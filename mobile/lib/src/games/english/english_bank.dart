// Grammar and vocabulary items for lower-secondary English (grades 6-9),
// written for this app. Each entry: (topic, sentence with ___, answer,
// distractors, rule hint).

typedef EnglishEntry = (
  String topic,
  String sentence,
  String answer,
  List<String> distractors,
  String hint,
);

const grade6Bank = <EnglishEntry>[
  (
    'Present simple',
    'She ___ to school by bus every day.',
    'goes',
    ['go', 'going', 'went'],
    'He/she/it + verb-s in the present simple.'
  ),
  (
    'Present simple',
    'My brother ___ football on Sundays.',
    'plays',
    ['play', 'playing', 'played'],
    'He/she/it + verb-s in the present simple.'
  ),
  (
    'Questions',
    '___ you like ice cream?',
    'Do',
    ['Does', 'Are', 'Is'],
    'Questions with I/you/we/they use Do.'
  ),
  (
    'Negatives',
    'He ___ have a pet.',
    "doesn't",
    ["don't", "isn't", 'not'],
    "He/she/it: doesn't + base verb."
  ),
  (
    'Articles',
    'I saw ___ elephant at the zoo.',
    'an',
    ['a', 'the', 'some'],
    'Use an before a vowel sound.'
  ),
  (
    'Articles',
    'She is ___ honest girl.',
    'an',
    ['a', 'the', 'any'],
    'Honest starts with a vowel sound, so: an honest girl.'
  ),
  (
    'Articles',
    '___ sun rises in the east.',
    'The',
    ['A', 'An', 'Some'],
    'There is only one sun: use the.'
  ),
  (
    'Time prepositions',
    'My birthday is ___ May.',
    'in',
    ['on', 'at', 'to'],
    'in + months and years.'
  ),
  (
    'Time prepositions',
    'We have English ___ Monday.',
    'on',
    ['in', 'at', 'by'],
    'on + days and dates.'
  ),
  (
    'Time prepositions',
    'The film starts ___ 7 o\'clock.',
    'at',
    ['in', 'on', 'for'],
    'at + clock times.'
  ),
  (
    'Plurals',
    'I have two ___.',
    'children',
    ['childs', 'childrens', 'child'],
    'Irregular plural: child → children.'
  ),
  (
    'Plurals',
    'Wash your ___ before dinner.',
    'hands',
    ['handes', 'hand', "hand's"],
    'Most plurals add -s.'
  ),
  (
    'Pronouns',
    "This bag belongs to my sister. It's ___.",
    'hers',
    ['her', 'she', "her's"],
    'Possessive pronoun: hers (no apostrophe).'
  ),
  (
    'There is / are',
    'There ___ two cats in the garden.',
    'are',
    ['is', 'am', 'be'],
    'There are + plural noun.'
  ),
  (
    'Can',
    "Birds ___ fly, but penguins can't.",
    'can',
    ["can't", 'cans', 'do'],
    'can + base verb = ability.'
  ),
  (
    'Past simple',
    'Yesterday I ___ a big fish.',
    'caught',
    ['catched', 'catch', 'catches'],
    'Irregular: catch → caught.'
  ),
  (
    'Past simple',
    'We ___ to the beach last summer.',
    'went',
    ['goed', 'go', 'gone'],
    'Irregular: go → went.'
  ),
  (
    'Past simple',
    'She ___ a letter to her friend yesterday.',
    'wrote',
    ['writed', 'write', 'written'],
    'Irregular: write → wrote.'
  ),
  (
    'Comparatives',
    'An elephant is ___ than a horse.',
    'bigger',
    ['more big', 'biggest', 'big'],
    'Short adjective: double the consonant + -er.'
  ),
  (
    'Comparatives',
    'My bag is ___ than yours.',
    'heavier',
    ['heavyer', 'more heavy', 'heaviest'],
    'Adjective ending in -y: y → ier.'
  ),
  (
    'Present continuous',
    'Look! The baby ___.',
    'is sleeping',
    ['sleeps', 'sleep', 'are sleeping'],
    'Happening now: am/is/are + verb-ing.'
  ),
  (
    'Present continuous',
    'They ___ TV right now.',
    'are watching',
    ['watch', 'is watching', 'watches'],
    'Happening now: am/is/are + verb-ing.'
  ),
  (
    'Pronouns',
    'I like Tom. I play with ___ every day.',
    'him',
    ['he', 'his', "he's"],
    'After a verb or preposition use object pronouns: him.'
  ),
  (
    'Question words',
    '___ is your birthday? – In June.',
    'When',
    ['Where', 'Who', 'What'],
    'When asks about time.'
  ),
  (
    'Question words',
    '___ do you live? – In Hanoi.',
    'Where',
    ['When', 'Who', 'Why'],
    'Where asks about place.'
  ),
  (
    'Some / any',
    'Is there ___ milk in the fridge?',
    'any',
    ['some', 'many', 'a'],
    'Questions and negatives usually use any.'
  ),
  (
    'Imperatives',
    "___ the door, please. It's cold.",
    'Close',
    ['Closing', 'Closes', 'To close'],
    'Imperative = base verb.'
  ),
];

const grade7Bank = <EnglishEntry>[
  (
    'Past continuous',
    'I ___ dinner when the phone rang.',
    'was having',
    ['had', 'am having', 'were having'],
    'Long action interrupted: was/were + verb-ing.'
  ),
  (
    'Past continuous',
    'While they ___ football, it started to rain.',
    'were playing',
    ['was playing', 'played', 'are playing'],
    'Long action interrupted: was/were + verb-ing.'
  ),
  (
    'Present perfect',
    'I have ___ been to Da Nang.',
    'never',
    ['ever', 'yet', 'ago'],
    'never = at no time.'
  ),
  (
    'Present perfect',
    'Have you ___ seen a dolphin?',
    'ever',
    ['never', 'yet', 'already'],
    'ever = at any time (questions).'
  ),
  (
    'Present perfect',
    'She has just ___ her homework.',
    'finished',
    ['finish', 'finishing', 'finishes'],
    'have/has + past participle.'
  ),
  (
    'Superlatives',
    'Mount Everest is ___ mountain in the world.',
    'the highest',
    ['the higher', 'highest', 'the most high'],
    'Superlative: the + adjective-est.'
  ),
  (
    'Superlatives',
    'This is ___ book I have ever read.',
    'the most interesting',
    ['the interestingest', 'more interesting', 'most interesting'],
    'Long adjective: the most + adjective.'
  ),
  (
    'Comparatives',
    'My cold is ___ today than yesterday.',
    'worse',
    ['badder', 'worst', 'more bad'],
    'Irregular: bad → worse → worst.'
  ),
  (
    'Much / many',
    'How ___ students are in your class?',
    'many',
    ['much', 'any', 'lot'],
    'many + countable plural nouns.'
  ),
  (
    'Much / many',
    "We don't have ___ time.",
    'much',
    ['many', 'few', 'lots'],
    'much + uncountable nouns.'
  ),
  (
    'A little / a few',
    'There is ___ sugar left.',
    'a little',
    ['a few', 'many', 'several'],
    'a little + uncountable nouns.'
  ),
  (
    'Future',
    'Look at those dark clouds! It ___ rain.',
    'is going to',
    ['will', 'rains', 'is raining'],
    'Evidence now → be going to.'
  ),
  (
    'Future',
    "I'm thirsty. – I ___ get you some water.",
    'will',
    ['am going to', 'am', 'would'],
    'Decision at the moment of speaking → will.'
  ),
  (
    'Place prepositions',
    'The cat is hiding ___ the bed.',
    'under',
    ['on', 'at', 'between'],
    'under = below something.'
  ),
  (
    'Place prepositions',
    'Our school is ___ the bank and the post office.',
    'between',
    ['among', 'behind', 'opposite'],
    'between + two things.'
  ),
  (
    'Should',
    'You have a fever. You ___ see a doctor.',
    'should',
    ["shouldn't", "mustn't", "can't"],
    'should = good advice.'
  ),
  (
    'Possessive \'s',
    'This is ___ room.',
    "the children's",
    ["the childrens'", 'the childrens', 'the children'],
    "Plural not ending in -s: add 's."
  ),
  (
    'Adverbs',
    'She sings ___.',
    'beautifully',
    ['beautiful', 'beauty', 'more beautiful'],
    'An adverb describes a verb: adjective + -ly.'
  ),
  (
    'Adverbs',
    'He drives very ___.',
    'carefully',
    ['careful', 'care', 'carefulness'],
    'An adverb describes a verb: adjective + -ly.'
  ),
  (
    'Past simple',
    '___ you visit your grandparents last weekend?',
    'Did',
    ['Do', 'Were', 'Have'],
    'Past simple questions: Did + subject + base verb.'
  ),
  (
    'Past simple',
    "She didn't ___ the bus this morning.",
    'catch',
    ['caught', 'catches', 'catching'],
    "didn't + base verb."
  ),
  (
    'Too / enough',
    'This coffee is too hot ___.',
    'to drink',
    ['drinking', 'for drink', 'drink'],
    'too + adjective + to-infinitive.'
  ),
  (
    'Too / enough',
    "He isn't old ___ to drive.",
    'enough',
    ['too', 'very', 'so'],
    'adjective + enough + to-infinitive.'
  ),
  (
    'Verb patterns',
    'I enjoy ___ comics.',
    'reading',
    ['to read', 'read', 'reads'],
    'enjoy + verb-ing.'
  ),
  (
    'For / since',
    'I have lived here ___ 2015.',
    'since',
    ['for', 'from', 'in'],
    'since + a point in time.'
  ),
  (
    'For / since',
    'They have known each other ___ ten years.',
    'for',
    ['since', 'during', 'ago'],
    'for + a period of time.'
  ),
  (
    'Uncountable nouns',
    'Can I have ___ advice?',
    'some',
    ['an', 'many', 'a few'],
    'advice is uncountable: some advice.'
  ),
  (
    'Must',
    'You ___ use your phone during the test.',
    "mustn't",
    ['must', "needn't", 'should'],
    "mustn't = it is not allowed."
  ),
];

const grade8Bank = <EnglishEntry>[
  (
    'Present perfect',
    "I ___ my keys. I can't find them anywhere.",
    'have lost',
    ['lost', 'was losing', 'lose'],
    'Past action with a result now → present perfect.'
  ),
  (
    'Past simple',
    'We ___ Hue in 2019.',
    'visited',
    ['have visited', 'visit', 'were visiting'],
    'Finished time (in 2019) → past simple.'
  ),
  (
    'First conditional',
    'If it rains tomorrow, we ___ at home.',
    'will stay',
    ['stay', 'would stay', 'stayed'],
    'If + present simple, will + base verb.'
  ),
  (
    'First conditional',
    'If you ___ hard, you will pass the exam.',
    'study',
    ['will study', 'studied', 'would study'],
    'If + present simple, will + base verb.'
  ),
  (
    'Second conditional',
    'If I ___ a bird, I would fly around the world.',
    'were',
    ['am', 'will be', 'would be'],
    'Unreal present: If + past (were), would + verb.'
  ),
  (
    'Second conditional',
    'If I had more time, I ___ learn the guitar.',
    'would',
    ['will', 'can', 'did'],
    'Unreal present: If + past, would + verb.'
  ),
  (
    'Passive',
    'English ___ in many countries.',
    'is spoken',
    ['speaks', 'is speaking', 'spoke'],
    'Passive: am/is/are + past participle.'
  ),
  (
    'Passive',
    'This bridge ___ in 1990.',
    'was built',
    ['built', 'is built', 'was building'],
    'Past passive: was/were + past participle.'
  ),
  (
    'Passive',
    'The letters ___ every morning.',
    'are delivered',
    ['deliver', 'are delivering', 'delivered'],
    'Passive: am/is/are + past participle.'
  ),
  (
    'Used to',
    'My grandfather ___ fish in this river when he was young.',
    'used to',
    ['use to', 'was used to', 'uses to'],
    'used to + base verb = a past habit.'
  ),
  (
    'Relative clauses',
    'The girl ___ won the prize is my cousin.',
    'who',
    ['which', 'where', 'whose'],
    'who for people.'
  ),
  (
    'Relative clauses',
    'This is the house ___ I was born.',
    'where',
    ['which', 'who', 'when'],
    'where = in which (a place).'
  ),
  (
    'Relative clauses',
    'The phone ___ I bought last week is broken.',
    'which',
    ['who', 'where', 'whose'],
    'which for things.'
  ),
  (
    'Verb patterns',
    'She decided ___ a new language.',
    'to learn',
    ['learning', 'learn', 'learned'],
    'decide + to-infinitive.'
  ),
  (
    'Verb patterns',
    'Would you mind ___ the window?',
    'opening',
    ['to open', 'open', 'opened'],
    'mind + verb-ing.'
  ),
  (
    'Verb patterns',
    'They avoided ___ about the problem.',
    'talking',
    ['to talk', 'talk', 'talked'],
    'avoid + verb-ing.'
  ),
  (
    'Have to',
    'At many schools, students ___ wear uniforms.',
    'have to',
    ['has to', 'must to', 'having to'],
    'have to + base verb = a rule.'
  ),
  (
    "Don't have to",
    'You ___ bring food; we have plenty.',
    "don't have to",
    ["mustn't", "haven't to", 'not have to'],
    "don't have to = it is not necessary."
  ),
  (
    'As ... as',
    'My phone is not as expensive ___ yours.',
    'as',
    ['than', 'like', 'so'],
    'not as + adjective + as.'
  ),
  (
    'Reflexive pronouns',
    'She hurt ___ while cooking.',
    'herself',
    ['her', 'himself', 'hers'],
    'Same person as the subject → -self.'
  ),
  (
    'Past perfect',
    'When we arrived, the film ___ already started.',
    'had',
    ['has', 'was', 'have'],
    'The earlier past action → had + past participle.'
  ),
  (
    'Linking words',
    'It was raining, ___ we stayed inside.',
    'so',
    ['but', 'because', 'although'],
    'so introduces a result.'
  ),
  (
    'Linking words',
    'I like tea, ___ my sister prefers coffee.',
    'but',
    ['so', 'because', 'or'],
    'but shows contrast.'
  ),
  (
    'Question tags',
    'You are a student, ___?',
    "aren't you",
    ['are you', "isn't it", "don't you"],
    'Positive sentence → negative tag with the same verb.'
  ),
  (
    'Quantifiers',
    '___ of my friends like K-pop.',
    'Most',
    ['Much', 'The most', 'Mostly'],
    'most of + plural noun.'
  ),
  (
    'Phrasal verbs',
    'Please ___ your shoes before entering.',
    'take off',
    ['take on', 'take up', 'take in'],
    'take off = remove clothes or shoes.'
  ),
  (
    '-ed / -ing adjectives',
    'I was ___ by the long speech.',
    'bored',
    ['boring', 'bore', 'boredom'],
    '-ed describes how you feel.'
  ),
  (
    '-ed / -ing adjectives',
    'The film was really ___.',
    'exciting',
    ['excited', 'excite', 'excitement'],
    '-ing describes what causes the feeling.'
  ),
];

const grade9Bank = <EnglishEntry>[
  (
    'Reported speech',
    'She said that she ___ tired.',
    'was',
    ['is', 'has been', 'will be'],
    'Reported speech moves present → past.'
  ),
  (
    'Reported speech',
    'He told me he ___ call me the next day.',
    'would',
    ['will', 'can', 'shall'],
    'Reported speech: will → would.'
  ),
  (
    'Reported questions',
    'They asked me where I ___.',
    'lived',
    ['do I live', 'did I live', 'live'],
    'Reported questions: statement word order + backshift.'
  ),
  (
    'Third conditional',
    'If you had studied, you ___ the test.',
    'would have passed',
    ['would pass', 'will pass', 'passed'],
    'If + had + past participle, would have + past participle.'
  ),
  (
    'Third conditional',
    "If she ___ the bus, she wouldn't have been late.",
    "hadn't missed",
    ["didn't miss", "wouldn't miss", "hasn't missed"],
    'If + had + past participle, would have + past participle.'
  ),
  (
    'Wish',
    'I wish I ___ taller.',
    'were',
    ['am', 'will be', 'have been'],
    'wish + past for a present situation.'
  ),
  (
    'Wish',
    'I wish I ___ harder last year.',
    'had studied',
    ['studied', 'have studied', 'would study'],
    'wish + past perfect for a past situation.'
  ),
  (
    'Passive',
    'The homework ___ already been done.',
    'has',
    ['have', 'is', 'was'],
    'Present perfect passive: has/have been + past participle.'
  ),
  (
    'Passive',
    'The new school ___ next year.',
    'will be opened',
    ['will open', 'is opening', 'opens'],
    'Future passive: will be + past participle.'
  ),
  (
    'Passive',
    'Mobile phones must ___ off during the exam.',
    'be turned',
    ['turn', 'turned', 'be turning'],
    'Modal passive: modal + be + past participle.'
  ),
  (
    'Contrast',
    '___ the rain, we went for a walk.',
    'Despite',
    ['Although', 'Because', 'Even'],
    'Despite + noun / verb-ing.'
  ),
  (
    'Contrast',
    '___ it was late, he kept working.',
    'Although',
    ['Despite', 'In spite', 'Because of'],
    'Although + clause (subject + verb).'
  ),
  (
    'Word formation',
    'The ___ of the bridge took two years.',
    'construction',
    ['construct', 'constructive', 'constructed'],
    'Noun suffix -ion.'
  ),
  (
    'Word formation',
    'She is a very ___ person; she always helps others.',
    'helpful',
    ['helpless', 'help', 'helping'],
    '-ful = full of.'
  ),
  (
    'Word formation',
    'The test was ___ easy. Everyone passed.',
    'surprisingly',
    ['surprising', 'surprise', 'surprised'],
    'An adverb can describe an adjective.'
  ),
  (
    'Word formation',
    'Air ___ is a serious problem in big cities.',
    'pollution',
    ['pollute', 'polluted', 'polluting'],
    'Noun suffix -ion.'
  ),
  (
    'Relative clauses',
    'Hanoi, ___ is the capital of Vietnam, has many lakes.',
    'which',
    ['that', 'who', 'where'],
    'Non-defining clause: which, never that.'
  ),
  (
    'Relative clauses',
    'My teacher, ___ husband is a doctor, lives near me.',
    'whose',
    ['who', 'which', 'whom'],
    'whose = belonging to that person.'
  ),
  (
    'Causative',
    'I had my hair ___ yesterday.',
    'cut',
    ['to cut', 'cutting', 'cuts'],
    'have something + past participle.'
  ),
  (
    'Present perfect continuous',
    'She ___ English for five years.',
    'has been learning',
    ['is learning', 'learns', 'learned'],
    'Started in the past and still going on.'
  ),
  (
    'Deduction',
    'He ___ be at home; the lights are on.',
    'must',
    ["can't", "mustn't", "needn't"],
    'must = I am almost sure it is true.'
  ),
  (
    'Deduction',
    'She ___ be hungry. She has just eaten.',
    "can't",
    ['must', "mustn't", "needn't"],
    "can't = I am sure it is not true."
  ),
  (
    'Phrasal verbs',
    "Can you ___ my cat while I'm away?",
    'look after',
    ['look for', 'look up', 'look into'],
    'look after = take care of.'
  ),
  (
    'Phrasal verbs',
    'We ran ___ milk, so I went to the shop.',
    'out of',
    ['away from', 'off', 'into'],
    'run out of = have none left.'
  ),
  (
    'Verb patterns',
    'She is good at ___ problems.',
    'solving',
    ['solve', 'to solve', 'solved'],
    'After a preposition use verb-ing.'
  ),
  (
    'Verb patterns',
    'He suggested ___ to the museum.',
    'going',
    ['to go', 'go', 'went'],
    'suggest + verb-ing.'
  ),
  (
    'Be used to',
    'I am used to ___ up early.',
    'getting',
    ['get', 'got', 'to get'],
    'be used to + verb-ing = be accustomed to.'
  ),
  (
    'So / such',
    'It was ___ a beautiful day that we went to the beach.',
    'such',
    ['so', 'very', 'too'],
    'such + a + adjective + noun.'
  ),
];
