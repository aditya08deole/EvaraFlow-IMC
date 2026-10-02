/**
 * Demo scope (max ~2 devices): no Firebase Storage caching. The Drive file
 * is only ever read by building a direct Google CDN URL from its id — this
 * backend never downloads or re-uploads the bytes. That only works because
 * the destination Drive folder is shared "Anyone with the link" (Viewer);
 * if that sharing setting is ever removed, images stop rendering.
 */

export function driveImageUrls(fileId: string): {
  storageUrl: string;
  thumbUrl: string;
} {
  return {
    storageUrl: `https://lh3.googleusercontent.com/d/${fileId}=w1600`,
    thumbUrl: `https://lh3.googleusercontent.com/d/${fileId}=w400`,
  };
}
