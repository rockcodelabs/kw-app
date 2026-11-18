<?php
/**
 * Read/edit the "Easy Accordion" sections of the course page (post 408).
 *
 * Run through WP-CLI on the server (see SKILL.md):
 *   wp eval-file accordion.php list
 *   wp eval-file accordion.php get <index>
 *   wp eval-file accordion.php set <index> <html-file>
 *
 * The data is a PHP-serialized array stored in post meta, so never edit it as
 * text; this script round-trips it through get/update_post_meta.
 */

$post_id  = 408;
$meta_key = 'sp_eap_upload_options';

$cmd  = isset( $args[0] ) ? $args[0] : 'list';
$opts = get_post_meta( $post_id, $meta_key, true );

if ( ! is_array( $opts ) || ! isset( $opts['accordion_content_source'] ) ) {
	WP_CLI::error( "Meta $meta_key of post $post_id has an unexpected structure." );
}

$items = $opts['accordion_content_source'];

switch ( $cmd ) {
	case 'list':
		foreach ( $items as $i => $item ) {
			printf( "%d\t%s\t(%d chars)\n", $i, $item['accordion_content_title'], strlen( $item['accordion_content_description'] ) );
		}
		break;

	case 'get':
		$i = isset( $args[1] ) ? (int) $args[1] : -1;
		if ( ! isset( $items[ $i ] ) ) {
			WP_CLI::error( "No accordion item with index $i." );
		}
		echo $items[ $i ]['accordion_content_description'];
		break;

	case 'set':
		$i    = isset( $args[1] ) ? (int) $args[1] : -1;
		$file = isset( $args[2] ) ? $args[2] : '';
		if ( ! isset( $items[ $i ] ) ) {
			WP_CLI::error( "No accordion item with index $i." );
		}
		if ( ! is_readable( $file ) ) {
			WP_CLI::error( "Cannot read $file." );
		}
		$new = file_get_contents( $file );
		if ( '' === trim( $new ) ) {
			WP_CLI::error( 'Refusing to save empty content.' );
		}
		if ( $items[ $i ]['accordion_content_description'] === $new ) {
			WP_CLI::warning( 'Content is identical, nothing to do.' );
			break;
		}
		$opts['accordion_content_source'][ $i ]['accordion_content_description'] = $new;
		// update_post_meta() unslashes its input, so slash first to keep backslashes intact.
		update_post_meta( $post_id, $meta_key, wp_slash( $opts ) );

		$check = get_post_meta( $post_id, $meta_key, true );
		if ( $check['accordion_content_source'][ $i ]['accordion_content_description'] !== $new ) {
			WP_CLI::error( 'Saved value does not match what was sent!' );
		}
		WP_CLI::success( "Updated item $i ({$items[ $i ]['accordion_content_title']})." );
		break;

	default:
		WP_CLI::error( "Unknown command '$cmd'. Use list | get <i> | set <i> <file>." );
}
