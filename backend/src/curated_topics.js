/**
 * Hand-picked reading material, fetched from Wikipedia (CC BY-SA, plain-text extracts). Speeches use
 * the English article about the speech (context plus quoted passages); biographies and history prefer
 * Simple English Wikipedia (easier B1-level prose) and fall back to English Wikipedia.
 *
 * The list is interleaved by category so any prefix is a balanced mix; the first 20 that pass the LLM
 * grading become the initial collection and the rest feed the weekly pick.
 */
const speeches = [
  'Gettysburg Address',
  'I Have a Dream',
  'We shall fight on the beaches',
  "Ain't I a Woman?",
  'Tryst with Destiny',
  'Blood, toil, tears and sweat',
  'Citizenship in a Republic',
  'Give me liberty, or give me death!',
  'Ich bin ein Berliner',
  'Four Freedoms',
  'Tear down this wall!',
  'Quit India speech',
  'Inaugural address of John F. Kennedy',
  'Cross of Gold speech',
  'A More Perfect Union (speech)'
].map((title) => ({ category: 'speech', title, hosts: ['en.wikipedia.org'] }));

const people = [
  'Marie Curie',
  'Nelson Mandela',
  'Leonardo da Vinci',
  'Rosa Parks',
  'Mahatma Gandhi',
  'Abraham Lincoln',
  'Albert Einstein',
  'Florence Nightingale',
  'Amelia Earhart',
  'Helen Keller',
  'Nikola Tesla',
  'Malala Yousafzai',
  'Ho Chi Minh',
  'Confucius',
  'Isaac Newton',
  'Mother Teresa',
  'Wright brothers',
  'Galileo Galilei'
].map((title) => ({ category: 'biography', title, hosts: ['simple.wikipedia.org', 'en.wikipedia.org'] }));

const history = [
  'Apollo 11',
  'Great Wall of China',
  'Titanic',
  'Berlin Wall',
  'Silk Road',
  'Industrial Revolution',
  'Magna Carta',
  'Great Pyramid of Giza',
  'Boston Tea Party',
  'Black Death',
  'Renaissance',
  'French Revolution',
  'Printing press',
  'Ancient Egypt',
  'Roman Empire',
  'Underground Railroad'
].map((title) => ({ category: 'history', title, hosts: ['simple.wikipedia.org', 'en.wikipedia.org'] }));

export const CURATED_TOPICS = interleave([speeches, people, history]);

function interleave(lists) {
  const longest = Math.max(...lists.map((list) => list.length));
  const merged = [];
  for (let index = 0; index < longest; index += 1) {
    for (const list of lists) {
      if (list[index]) {
        merged.push(list[index]);
      }
    }
  }
  return merged;
}
