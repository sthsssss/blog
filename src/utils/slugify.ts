export default function slugify(input: string) {
  return input
    .toString()
    .toLowerCase()
    .trim()
    // Replace spaces and underscores with hyphens
    .replace(/[_\s]+/g, '-')
    // Remove chars except word chars, hyphens, and Korean syllables
    .replace(/[^\w\-가-힣]/g, '')
    // Collapse multiple hyphens
    .replace(/-+/g, '-');
}
