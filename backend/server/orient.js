import { imageSize } from "image-size";

/**
 * Size of a picture as it looks when displayed. EXIF orientations 5 to 8 turn the picture on its
 * side, so its width and height swap. SAM and the phone both apply that turn, so we must too.
 */
export function orientedSize({ width, height, orientation }) {
  return (orientation ?? 1) >= 5 ? { width: height, height: width } : { width, height };
}

export function displaySize(buf) {
  return orientedSize(imageSize(buf));
}