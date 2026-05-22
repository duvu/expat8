-- Seed data: Memorization passages (public-domain speeches and civic texts)
-- Apply after 20260521_memorization_passages.sql.
-- These passages are inserted with status='pending_segmentation' so the worker will segment them.

INSERT INTO memorization_passages (
  id, title, language, raw_text, owner_type, owner_user_id, visibility,
  status, processing_error, segment_count, created_at, updated_at
)
VALUES
  (
    'passage_seed_gettysburg_address',
    'Gettysburg Address - Abraham Lincoln (1863)',
    'en',
    $$Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.

Now we are engaged in a great civil war, testing whether that nation, or any nation so conceived and so dedicated, can long endure. We are met on a great battle-field of that war.

It is for us the living, rather, to be dedicated here to the unfinished work which they who fought here have thus far so nobly advanced. It is rather for us to be here dedicated to the great task remaining before us: that government of the people, by the people, for the people, shall not perish from the earth.$$,
    'system', NULL, 'published', 'pending_segmentation', NULL, 0,
    '2026-05-21T00:00:00.000Z', '2026-05-21T00:00:00.000Z'
  ),
  (
    'passage_seed_second_inaugural',
    'Second Inaugural Address - Abraham Lincoln (1865)',
    'en',
    $$With malice toward none; with charity for all; with firmness in the right, as God gives us to see the right, let us strive on to finish the work we are in.

Let us bind up the nation's wounds, to care for him who shall have borne the battle and for his widow and his orphan, to do all which may achieve and cherish a just and lasting peace among ourselves and with all nations.$$,
    'system', NULL, 'published', 'pending_segmentation', NULL, 0,
    '2026-05-21T00:00:00.000Z', '2026-05-21T00:00:00.000Z'
  ),
  (
    'passage_seed_fdr_first_inaugural',
    'First Inaugural Address - Franklin D. Roosevelt (1933)',
    'en',
    $$This great Nation will endure as it has endured, will revive and will prosper. So, first of all, let me assert my firm belief that the only thing we have to fear is fear itself.

Nameless, unreasoning, unjustified terror paralyzes needed efforts to convert retreat into advance. In every dark hour of our national life a leadership of frankness and vigor has met with that understanding and support of the people themselves which is essential to victory.$$,
    'system', NULL, 'published', 'pending_segmentation', NULL, 0,
    '2026-05-21T00:00:00.000Z', '2026-05-21T00:00:00.000Z'
  ),
  (
    'passage_seed_jfk_inaugural',
    'Inaugural Address - John F. Kennedy (1961)',
    'en',
    $$Let every nation know, whether it wishes us well or ill, that we shall pay any price, bear any burden, meet any hardship, support any friend, oppose any foe, to assure the survival and the success of liberty.

And so, my fellow Americans: ask not what your country can do for you; ask what you can do for your country. My fellow citizens of the world: ask not what America will do for you, but what together we can do for the freedom of man.$$,
    'system', NULL, 'published', 'pending_segmentation', NULL, 0,
    '2026-05-21T00:00:00.000Z', '2026-05-21T00:00:00.000Z'
  ),
  (
    'passage_seed_man_in_the_arena',
    'The Man in the Arena - Theodore Roosevelt (1910)',
    'en',
    $$It is not the critic who counts; not the man who points out how the strong man stumbles, or where the doer of deeds could have done them better.

The credit belongs to the man who is actually in the arena, whose face is marred by dust and sweat and blood, who strives valiantly, who errs, who comes short again and again, because there is no effort without error and shortcoming.

If he fails, at least he fails while daring greatly, so that his place shall never be with those cold and timid souls who neither know victory nor defeat.$$,
    'system', NULL, 'published', 'pending_segmentation', NULL, 0,
    '2026-05-21T00:00:00.000Z', '2026-05-21T00:00:00.000Z'
  ),
  (
    'passage_seed_give_me_liberty',
    'Give Me Liberty - Patrick Henry (1775)',
    'en',
    $$It is in vain, sir, to extenuate the matter. Gentlemen may cry, Peace, Peace, but there is no peace. The war is actually begun.

The next gale that sweeps from the north will bring to our ears the clash of resounding arms. Our brethren are already in the field. Why stand we here idle?

Is life so dear, or peace so sweet, as to be purchased at the price of chains and slavery? Forbid it, Almighty God. I know not what course others may take; but as for me, give me liberty or give me death.$$,
    'system', NULL, 'published', 'pending_segmentation', NULL, 0,
    '2026-05-21T00:00:00.000Z', '2026-05-21T00:00:00.000Z'
  ),
  (
    'passage_seed_what_to_the_slave',
    'What to the Slave Is the Fourth of July - Frederick Douglass (1852)',
    'en',
    $$What, to the American slave, is your Fourth of July? I answer: a day that reveals to him, more than all other days in the year, the gross injustice and cruelty to which he is the constant victim.

To him, your celebration is a sham; your boasted liberty, an unholy license; your national greatness, swelling vanity; your sounds of rejoicing are empty and heartless. There is not a nation on the earth guilty of practices more shocking and bloody than are the people of the United States at this very hour.$$,
    'system', NULL, 'published', 'pending_segmentation', NULL, 0,
    '2026-05-21T00:00:00.000Z', '2026-05-21T00:00:00.000Z'
  )
ON CONFLICT (id) DO NOTHING;
