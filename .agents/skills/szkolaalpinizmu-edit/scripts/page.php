<?php
/**
 * Read/replace the post_content of a WordPress page from a file.
 *
 * Run through WP-CLI on the server (see SKILL.md):
 *   wp eval-file page.php get <post_id>
 *   wp eval-file page.php set <post_id> <html-file>
 *
 * Why not `wp post update`? WP-CLI 2.3.0 ignores stdin ('-') for updates, and
 * running as no user would apply KSES filtering that strips block markup.
 */

$cmd = isset( $args[0] ) ? $args[0] : '';
$id  = isset( $args[1] ) ? (int) $args[1] : 0;
$post = $id ? get_post( $id ) : null;

if ( ! $post ) {
	WP_CLI::error( "Post $id not found." );
}

switch ( $cmd ) {
	case 'get':
		echo $post->post_content;
		break;

	case 'set':
		$file = isset( $args[2] ) ? $args[2] : '';
		if ( ! is_readable( $file ) ) {
			WP_CLI::error( "Cannot read $file." );
		}
		$new = file_get_contents( $file );
		if ( strlen( trim( $new ) ) < 100 ) {
			WP_CLI::error( 'Refusing to save (almost) empty content.' );
		}
		if ( $new === $post->post_content ) {
			WP_CLI::warning( 'Content is identical, nothing to do.' );
			break;
		}

		kses_remove_filters(); // keep Gutenberg markup (button, data-*, style) intact

		$result = wp_update_post( wp_slash( array( 'ID' => $id, 'post_content' => $new ) ), true );
		if ( is_wp_error( $result ) ) {
			WP_CLI::error( $result->get_error_message() );
		}

		clean_post_cache( $id );
		$saved = get_post( $id )->post_content;
		if ( $saved !== $new ) {
			WP_CLI::error( 'Saved content differs from the file! Restore the backup.' );
		}
		WP_CLI::success( "Updated post $id (" . strlen( $saved ) . ' bytes), saved content matches the file.' );
		break;

	default:
		WP_CLI::error( 'Usage: get <post_id> | set <post_id> <file>' );
}
