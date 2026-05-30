import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import slugify from '../utils/slugify';

export async function GET(context) {
  const posts = await getCollection('blog');
  return rss({
    title: 'Astro Learner | Blog',
    description: 'My journey learning Astro',
    site: context.site,
    items: posts.map((post) => ({
      title: post.data.title,
      pubDate: post.data.pubDate,
      description: post.data.description,
      link: `/posts/${slugify(post.data.title)}/`,
    })),
    customData: `<language>en-us</language>`,
  });
}