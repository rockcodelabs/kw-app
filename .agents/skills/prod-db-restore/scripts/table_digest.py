#!/usr/bin/env python3
"""Compare a pg_dump (plain SQL, .sql.gz) with a restored Postgres database.

Prints table names, counts and PASS/FAIL only - never row contents.

  table_digest.py verify DUMP.sql.gz --psql "<command that runs psql against the DB>" [--after-migrate]

--psql is a shell-style command that runs psql against the target DB and reads SQL from stdin
(stdin avoids quoting problems through ssh), e.g.
  "ssh -o BatchMode=yes rege@pi5main.local docker exec -i kw-app-staging-postgres psql -U staging_user -d NEWDB -X -q -At"
so the same checker works for any target (staging, new prod, a local container).

What is compared
  * every table: row count + order-independent SHA-256 digest of all rows
    (float4/float8 columns are normalised: PG 10 and PG 16 print floats differently)
  * every sequence: last_value vs the dump's setval()
  * structure: tables, sequences, foreign keys, primary/unique constraints, indexes (public schema)
--after-migrate: the target may legitimately be AHEAD of the dump (new migrations), so
  schema_migrations only has to be a superset and structure counts only have to be >=.
Exit code 0 = all good, 1 = mismatch, 2 = usage/connection error.
"""
import argparse
import gzip
import hashlib
import re
import shlex
import struct
import subprocess
import sys

COPY_RE = re.compile(r'^COPY (\S+) \((.*)\) FROM stdin;$')
SETVAL_RE = re.compile(r"^SELECT pg_catalog\.setval\('([^']+)', (-?\d+), (true|false)\);$")
MASK = (1 << 256) - 1


def split_cols(s):
    return [c.strip().strip('"') for c in s.split(', ')]


def norm_float(v, kind):
    if v == '\\N':
        return v
    f = float(v)
    if kind == 'real':
        f = struct.unpack('f', struct.pack('f', f))[0]
    return repr(f)


def row_digest(line, float_idx):
    if float_idx:
        parts = line.split('\t')
        for i, kind in float_idx:
            if i < len(parts):
                parts[i] = norm_float(parts[i], kind)
        line = '\t'.join(parts)
    return int.from_bytes(hashlib.sha256(line.encode('utf-8', 'surrogateescape')).digest(), 'big')


def psql(prefix, sql):
    r = subprocess.run(shlex.split(prefix), input=sql, capture_output=True, text=True)
    if r.returncode:
        print('psql failed: ' + r.stderr.strip()[:300], file=sys.stderr)
        sys.exit(2)
    return r.stdout


def float_columns(prefix):
    out = psql(prefix, "select table_name||'.'||column_name||'|'||data_type from information_schema.columns "
                       "where table_schema='public' and data_type in ('double precision','real')")
    res = {}
    for line in out.splitlines():
        key, kind = line.rsplit('|', 1)
        res[key] = 'real' if kind == 'real' else 'double'
    return res


def short(table):
    return table.split('.', 1)[1].strip('"')


def digest_dump(path, fcols):
    tables, seqs, struct_counts = {}, {}, dict(tables=0, sequences=0, fks=0, pk_unique=0, indexes=0)
    cur = None
    with gzip.open(path, 'rt', encoding='utf-8', errors='surrogateescape', newline='\n') as fh:
        for raw in fh:
            line = raw.rstrip('\n')
            if cur is not None:
                if line == '\\.':
                    tables[cur['name']] = (cur['rows'], cur['sum'], cur['cols'])
                    cur = None
                else:
                    cur['rows'] += 1
                    cur['sum'] = (cur['sum'] + row_digest(line, cur['fidx'])) & MASK
                continue
            m = COPY_RE.match(line)
            if m:
                name, cols = m.group(1), split_cols(m.group(2))
                t = short(name)
                fidx = [(i, fcols[f'{t}.{c}']) for i, c in enumerate(cols) if f'{t}.{c}' in fcols]
                cur = dict(name=name, cols=cols, rows=0, sum=0, fidx=fidx)
                continue
            m = SETVAL_RE.match(line)
            if m:
                seqs[m.group(1)] = (int(m.group(2)), m.group(3) == 'true')
            elif line.startswith('CREATE TABLE '):
                struct_counts['tables'] += 1
            elif line.startswith('CREATE SEQUENCE '):
                struct_counts['sequences'] += 1
            elif re.match(r'^CREATE (UNIQUE )?INDEX ', line):
                struct_counts['indexes'] += 1
            elif re.match(r'^\s+ADD CONSTRAINT .* FOREIGN KEY', line):
                struct_counts['fks'] += 1
            elif re.match(r'^\s+ADD CONSTRAINT .* (PRIMARY KEY|UNIQUE)', line):
                struct_counts['pk_unique'] += 1
                struct_counts['indexes'] += 1
    return tables, seqs, struct_counts


def digest_db_table(prefix, name, cols, fcols):
    t = short(name)
    fidx = [(i, fcols[f'{t}.{c}']) for i, c in enumerate(cols) if f'{t}.{c}' in fcols]
    collist = ', '.join('"%s"' % c for c in cols)
    sql = f'COPY (SELECT {collist} FROM {name}) TO STDOUT;\n'
    rows, acc = 0, 0
    p = subprocess.Popen(shlex.split(prefix), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    p.stdin.write(sql.encode())
    p.stdin.close()
    for raw in p.stdout:
        line = raw.decode('utf-8', 'surrogateescape').rstrip('\n')
        rows += 1
        acc = (acc + row_digest(line, fidx)) & MASK
    err = p.stderr.read().decode()
    if p.wait():
        print(f'COPY failed for {name}: {err.strip()[:200]}', file=sys.stderr)
        sys.exit(2)
    return rows, acc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mode', choices=['verify'])
    ap.add_argument('dump')
    ap.add_argument('--psql', required=True)
    ap.add_argument('--after-migrate', action='store_true')
    a = ap.parse_args()

    fcols = float_columns(a.psql)
    print(f'float columns normalised: {len(fcols)}')
    tables, seqs, sc = digest_dump(a.dump, fcols)
    print(f'dump: {len(tables)} tables with data, {sum(v[0] for v in tables.values())} rows total')

    bad = []
    ok = 0
    for name, (rows, acc, cols) in sorted(tables.items()):
        t = short(name)
        if t == 'schema_migrations' and a.after_migrate:
            have = int(psql(a.psql, 'select count(*) from schema_migrations').strip())
            if have < rows:
                bad.append(f'{name}: target has {have} migrations, dump has {rows}')
            else:
                ok += 1
                print(f'  ok  {name:<55} dump={rows} target={have} (superset allowed after migrate)')
            continue
        grows, gacc = digest_db_table(a.psql, name, cols, fcols)
        if t == 'ar_internal_metadata' and a.after_migrate and grows == rows:
            ok += 1
            print(f'  ok  {name:<55} {rows} rows (content may change on migrate)')
            continue
        if grows != rows:
            bad.append(f'{name}: row count dump={rows} target={grows}')
        elif gacc != acc:
            bad.append(f'{name}: {rows} rows, content digest differs')
        else:
            ok += 1
            print(f'  ok  {name:<55} {rows} rows')

    # tables that exist in the target but were not in the dump's data
    extra = psql(a.psql, "select tablename from pg_tables where schemaname='public' order by 1").split()
    in_dump = {short(n) for n in tables}
    ddl_only = [t for t in extra if t not in in_dump]
    if ddl_only:
        nonempty = []
        for t in ddl_only:
            n = int(psql(a.psql, f'select count(*) from public."{t}"').strip())
            if n:
                nonempty.append(f'{t}({n})')
        if nonempty and not a.after_migrate:
            bad.append('tables with rows in target but no data in dump: ' + ', '.join(nonempty))
        print(f'  info: {len(ddl_only)} public tables have no COPY block in the dump (empty in dump)')

    # sequences
    seq_rows = psql(a.psql, "select schemaname||'.'||sequencename||'|'||coalesce(last_value::text,'') from pg_sequences "
                            "where schemaname='public'").splitlines()
    tseq = dict(l.rsplit('|', 1) for l in seq_rows)
    seq_bad = 0
    for s, (n, called) in seqs.items():
        have = tseq.get(s)
        if have is None:
            bad.append(f'sequence {s} missing in target'); seq_bad += 1
        elif called and have != str(n):
            bad.append(f'sequence {s}: dump last_value={n} target={have or "NULL"}'); seq_bad += 1
        elif not called and have not in ('', str(n)):
            bad.append(f'sequence {s}: dump not-called target={have}'); seq_bad += 1
    print(f'  sequences: {len(seqs) - seq_bad}/{len(seqs)} match')

    # structure
    q = {
        'tables': "select count(*) from pg_tables where schemaname='public'",
        'sequences': "select count(*) from pg_sequences where schemaname='public'",
        'fks': "select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype='f'",
        'pk_unique': "select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','u')",
        'indexes': "select count(*) from pg_indexes where schemaname='public'",
    }
    for k, sql in q.items():
        have = int(psql(a.psql, sql).strip())
        want = sc[k]
        good = have >= want if a.after_migrate else have == want
        print(f'  structure {k:<10} dump={want} target={have} {"ok" if good else "MISMATCH"}')
        if not good:
            bad.append(f'structure {k}: dump={want} target={have}')

    print()
    if bad:
        print(f'FAIL: {len(bad)} problem(s), {ok} tables ok')
        for b in bad:
            print('  - ' + b)
        sys.exit(1)
    print(f'PASS: {ok}/{len(tables)} tables identical (rows + content digest), sequences and structure match')


if __name__ == '__main__':
    main()
