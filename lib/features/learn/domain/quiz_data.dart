import 'library.dart';

// The quizzes that ship inside the app, transcribed from Resonant's
// QuizData.kt. Every word is the old text, unchanged, except two
// explanations where the old file holds UTF-8 mojibake (ph_q4, pa_q1);
// here those are the intended em dash.

const LibraryQuizSet quizPhotosynthesis = LibraryQuizSet(
  id: 'quiz_photosynthesis',
  title: 'Photosynthesis basics',
  category: 'Biology',
  questions: <LibraryQuizQuestion>[
    LibraryQuizQuestion(
      id: 'ph_q1',
      prompt: 'Which three things does photosynthesis need?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Sunlight, water, and carbon dioxide'),
        LibraryQuizOption(letter: 'B', text: 'Soil, wind, and heat'),
        LibraryQuizOption(letter: 'C', text: 'Only sunlight'),
        LibraryQuizOption(letter: 'D', text: 'Oxygen, salt, and shade'),
      ],
      correctIndex: 0,
      explanation:
          'A plant combines sunlight, water, and carbon dioxide to make its own sugar.',
    ),
    LibraryQuizQuestion(
      id: 'ph_q2',
      prompt: 'Where in the plant cell does photosynthesis take place?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'The nucleus'),
        LibraryQuizOption(letter: 'B', text: 'The mitochondria'),
        LibraryQuizOption(letter: 'C', text: 'The chloroplast'),
        LibraryQuizOption(letter: 'D', text: 'The cell wall'),
      ],
      correctIndex: 2,
      explanation:
          'Chloroplasts contain chlorophyll, the pigment that captures light energy.',
    ),
    LibraryQuizQuestion(
      id: 'ph_q3',
      prompt: 'What gas do plants release during photosynthesis?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Carbon dioxide'),
        LibraryQuizOption(letter: 'B', text: 'Nitrogen'),
        LibraryQuizOption(letter: 'C', text: 'Hydrogen'),
        LibraryQuizOption(letter: 'D', text: 'Oxygen'),
      ],
      correctIndex: 3,
      explanation:
          'Oxygen is the byproduct of splitting water molecules during the light reactions.',
    ),
    LibraryQuizQuestion(
      id: 'ph_q4',
      prompt: 'What is the green pigment in plants called?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Melanin'),
        LibraryQuizOption(letter: 'B', text: 'Chlorophyll'),
        LibraryQuizOption(letter: 'C', text: 'Carotene'),
        LibraryQuizOption(letter: 'D', text: 'Hemoglobin'),
      ],
      correctIndex: 1,
      explanation:
          'Chlorophyll absorbs red and blue light, reflecting green \u2014 which is why leaves look green.',
    ),
    LibraryQuizQuestion(
      id: 'ph_q5',
      prompt: 'What is the sugar produced by photosynthesis called?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Fructose'),
        LibraryQuizOption(letter: 'B', text: 'Starch'),
        LibraryQuizOption(letter: 'C', text: 'Glucose'),
        LibraryQuizOption(letter: 'D', text: 'Sucrose'),
      ],
      correctIndex: 2,
      explanation:
          'Plants produce glucose, which they use for energy or convert into starch for storage.',
    ),
  ],
);

const LibraryQuizSet quizCells = LibraryQuizSet(
  id: 'quiz_cells',
  title: 'Cells and their parts',
  category: 'Biology',
  questions: <LibraryQuizQuestion>[
    LibraryQuizQuestion(
      id: 'ce_q1',
      prompt: 'What controls what enters and leaves the cell?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'The nucleus'),
        LibraryQuizOption(letter: 'B', text: 'The cell membrane'),
        LibraryQuizOption(letter: 'C', text: 'The cytoplasm'),
        LibraryQuizOption(letter: 'D', text: 'The ribosome'),
      ],
      correctIndex: 1,
      explanation:
          'The cell membrane is selectively permeable, letting some substances through while blocking others.',
    ),
    LibraryQuizQuestion(
      id: 'ce_q2',
      prompt: 'Which organelle is known as the powerhouse of the cell?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'The nucleus'),
        LibraryQuizOption(letter: 'B', text: 'The vacuole'),
        LibraryQuizOption(letter: 'C', text: 'The ribosome'),
        LibraryQuizOption(letter: 'D', text: 'The mitochondria'),
      ],
      correctIndex: 3,
      explanation:
          'Mitochondria produce ATP through cellular respiration, supplying energy the cell needs.',
    ),
    LibraryQuizQuestion(
      id: 'ce_q3',
      prompt: 'What does the nucleus contain?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Chlorophyll'),
        LibraryQuizOption(letter: 'B', text: "The cell's DNA"),
        LibraryQuizOption(letter: 'C', text: 'Digestive enzymes'),
        LibraryQuizOption(letter: 'D', text: 'Water and salts'),
      ],
      correctIndex: 1,
      explanation:
          "The nucleus stores the cell's genetic instructions in the form of DNA.",
    ),
    LibraryQuizQuestion(
      id: 'ce_q4',
      prompt: 'Which structure is found in plant cells but NOT animal cells?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'The nucleus'),
        LibraryQuizOption(letter: 'B', text: 'The mitochondria'),
        LibraryQuizOption(letter: 'C', text: 'The cell wall'),
        LibraryQuizOption(letter: 'D', text: 'The ribosome'),
      ],
      correctIndex: 2,
      explanation:
          'Plant cells have a rigid cell wall made of cellulose that gives them structure. Animal cells do not.',
    ),
    LibraryQuizQuestion(
      id: 'ce_q5',
      prompt: 'What do ribosomes do?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Store water'),
        LibraryQuizOption(letter: 'B', text: 'Produce energy'),
        LibraryQuizOption(letter: 'C', text: 'Build proteins'),
        LibraryQuizOption(letter: 'D', text: 'Break down waste'),
      ],
      correctIndex: 2,
      explanation:
          "Ribosomes read the cell's genetic instructions and assemble proteins from amino acids.",
    ),
    LibraryQuizQuestion(
      id: 'ce_q6',
      prompt: 'What fills most of the space inside a cell?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Blood'),
        LibraryQuizOption(letter: 'B', text: 'Air'),
        LibraryQuizOption(letter: 'C', text: 'Cytoplasm'),
        LibraryQuizOption(letter: 'D', text: 'Chlorophyll'),
      ],
      correctIndex: 2,
      explanation:
          'Cytoplasm is the jelly-like fluid that fills the cell and suspends the organelles.',
    ),
  ],
);

const LibraryQuizSet quizEcosystems = LibraryQuizSet(
  id: 'quiz_ecosystems',
  title: 'Energy in ecosystems',
  category: 'Biology',
  questions: <LibraryQuizQuestion>[
    LibraryQuizQuestion(
      id: 'ec_q1',
      prompt: 'What do we call organisms that make their own food?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Consumers'),
        LibraryQuizOption(letter: 'B', text: 'Decomposers'),
        LibraryQuizOption(letter: 'C', text: 'Producers'),
        LibraryQuizOption(letter: 'D', text: 'Predators'),
      ],
      correctIndex: 2,
      explanation:
          'Producers, like plants and algae, make their own food through photosynthesis.',
    ),
    LibraryQuizQuestion(
      id: 'ec_q2',
      prompt: 'How much energy is typically passed from one trophic level to the next?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: '100 percent'),
        LibraryQuizOption(letter: 'B', text: '50 percent'),
        LibraryQuizOption(letter: 'C', text: '10 percent'),
        LibraryQuizOption(letter: 'D', text: '1 percent'),
      ],
      correctIndex: 2,
      explanation:
          'The 10 percent rule: about 90 percent of energy is lost as heat at each level.',
    ),
    LibraryQuizQuestion(
      id: 'ec_q3',
      prompt: 'What role do decomposers play in an ecosystem?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'They hunt prey'),
        LibraryQuizOption(letter: 'B', text: 'They produce oxygen'),
        LibraryQuizOption(
            letter: 'C', text: 'They break down dead matter and return nutrients to the soil'),
        LibraryQuizOption(letter: 'D', text: 'They store energy for other animals'),
      ],
      correctIndex: 2,
      explanation:
          'Decomposers like fungi and bacteria recycle nutrients by breaking down dead organisms.',
    ),
    LibraryQuizQuestion(
      id: 'ec_q4',
      prompt: 'What is a food chain?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'A list of what animals eat at a zoo'),
        LibraryQuizOption(
            letter: 'B', text: 'A sequence showing how energy moves from one organism to another'),
        LibraryQuizOption(letter: 'C', text: 'A diagram of all species in a habitat'),
        LibraryQuizOption(letter: 'D', text: 'A map of where animals hunt'),
      ],
      correctIndex: 1,
      explanation:
          'A food chain traces the path of energy from producers through successive consumers.',
    ),
    LibraryQuizQuestion(
      id: 'ec_q5',
      prompt: 'Which organism sits at the base of most food chains?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'A herbivore'),
        LibraryQuizOption(letter: 'B', text: 'A top predator'),
        LibraryQuizOption(letter: 'C', text: 'A plant or other producer'),
        LibraryQuizOption(letter: 'D', text: 'A decomposer'),
      ],
      correctIndex: 2,
      explanation:
          'Plants and other producers capture energy from the sun, making them the foundation of the food chain.',
    ),
  ],
);

const LibraryQuizSet quizPlantAdaptations = LibraryQuizSet(
  id: 'quiz_plant_adaptations',
  title: 'Plant adaptations',
  category: 'Biology',
  questions: <LibraryQuizQuestion>[
    LibraryQuizQuestion(
      id: 'pa_q1',
      prompt: 'Why do cacti have thick, waxy stems?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'To attract insects'),
        LibraryQuizOption(letter: 'B', text: 'To store water and reduce water loss'),
        LibraryQuizOption(letter: 'C', text: 'To absorb more sunlight'),
        LibraryQuizOption(letter: 'D', text: 'To grow taller than other plants'),
      ],
      correctIndex: 1,
      explanation:
          'The thick stem stores water and the waxy coating slows evaporation \u2014 critical in dry deserts.',
    ),
    LibraryQuizQuestion(
      id: 'pa_q2',
      prompt: 'What do spines on a cactus do?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Absorb water from rain'),
        LibraryQuizOption(letter: 'B', text: 'Produce food'),
        LibraryQuizOption(letter: 'C', text: 'Deter animals from eating the plant'),
        LibraryQuizOption(letter: 'D', text: 'Release oxygen faster'),
      ],
      correctIndex: 2,
      explanation:
          'Spines are modified leaves that protect the plant from being eaten by thirsty animals.',
    ),
    LibraryQuizQuestion(
      id: 'pa_q3',
      prompt: 'How do water lilies stay afloat?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'Their leaves are filled with air pockets'),
        LibraryQuizOption(letter: 'B', text: 'They have no roots'),
        LibraryQuizOption(letter: 'C', text: 'Their stems are made of wood'),
        LibraryQuizOption(letter: 'D', text: 'They absorb salt from the water'),
      ],
      correctIndex: 0,
      explanation:
          'Air pockets in the leaves reduce density and keep the leaf buoyant on the water surface.',
    ),
    LibraryQuizQuestion(
      id: 'pa_q4',
      prompt: 'Why do some plants in cold climates have dark-colored leaves?',
      options: <LibraryQuizOption>[
        LibraryQuizOption(letter: 'A', text: 'To blend in with the soil'),
        LibraryQuizOption(letter: 'B', text: 'To absorb more heat from sunlight'),
        LibraryQuizOption(letter: 'C', text: 'To store more water'),
        LibraryQuizOption(letter: 'D', text: 'To repel insects'),
      ],
      correctIndex: 1,
      explanation:
          'Darker pigments absorb more solar radiation, helping the plant stay warm in cold environments.',
    ),
  ],
);

/// All quiz sets in display order. The old app appends MoreContent quizzes;
/// those stay deferred, like the extra lessons.
const List<LibraryQuizSet> allQuizSets = <LibraryQuizSet>[
  quizPhotosynthesis,
  quizCells,
  quizEcosystems,
  quizPlantAdaptations,
];

/// The first set, for callers that need one quiz without a choice.
const LibraryQuizSet sampleQuiz = quizPhotosynthesis;

/// Whole-number percent, rounding down like the old results screen.
int quizPercent(int correct, int total) =>
    total <= 0 ? 0 : correct * 100 ~/ total;

/// The verdict under the big score. Old-exact bands.
String quizResultLabel(int correct, int total) {
  final int percent = quizPercent(correct, total);
  if (percent == 100) return 'Perfect score!';
  if (percent >= 80) return 'Great work.';
  if (percent >= 60) return 'Good effort.';
  return 'Keep practicing.';
}

/// The subtitle under "Results": "3 of 5 correct".
String quizResultsSubtitle(int correct, int total) => '$correct of $total correct';

/// What the results screen says on arrival. [missedCount] is empty on a
/// perfect score or on a retry round, so there is nothing to offer a retry of.
/// A named learner gets a personal cheer after the old line, which stays
/// word for word.
String quizResultsSpoken(int correct, int total, int missedCount,
    {String? name}) {
  final line =
      'You scored $correct out of $total. ${quizResultsInstructions(missedCount)}';
  final who = (name ?? '').trim();
  if (who.isEmpty) return line;
  final percent = quizPercent(correct, total);
  final String cheer;
  if (percent == 100) {
    cheer = 'Take a bow, $who.';
  } else if (percent >= 60) {
    cheer = 'Nice work, $who.';
  } else {
    cheer = 'You will get them next time, $who.';
  }
  return '$line $cheer';
}

/// The instructions after the score. A perfect score gets no dangling
/// "tap right edge" that does nothing.
String quizResultsInstructions(int missedCount) => missedCount > 0
    ? '$missedCount missed. Tap the right edge to retry those, or tap center to return home.'
    : 'Tap to return home.';

/// The hint line shown under the score card.
String quizResultsHint(int missedCount) => missedCount > 0
    ? 'Tap the right edge to retry the $missedCount missed, or the center to go back.'
    : 'Tap anywhere to go back.';

/// Announced when a retry round starts.
String quizRetryAnnouncement(int missedCount) =>
    'Retrying $missedCount missed question${missedCount == 1 ? '' : 's'}.';

/// The retry button's label.
String quizRetryLabel(int missedCount) => 'Retry $missedCount missed';

/// What the three-finger hold says on the results screen.
String quizResultsHoldSummary(int correct, int total, int missedCount) =>
    'Quiz Results. You scored $correct out of $total. ${quizResultsInstructions(missedCount)}';

/// The "Copy score" clipboard text. The retry round has no quiz of its
/// own, so an empty title stays generic.
String quizScoreShareText(int correct, int total, String quizTitle) =>
    quizTitle.isEmpty
        ? 'I scored $correct out of $total on a Resonant quiz!'
        : 'I scored $correct out of $total on $quizTitle with Resonant!';

/// One answer in the reader's queue: "Option B. The cell membrane."
String quizOptionUnit(String letter, String text) => 'Option $letter. $text.';

/// Announced when an option is tapped.
String quizSelectSpoken(String letter) =>
    'Option $letter selected. Swipe right to submit.';

/// Announced on submit: the verdict plus the explanation.
String quizSubmitSpoken(bool correct, String explanation) =>
    '${correct ? 'Correct' : 'Incorrect'}. $explanation';

/// Announced when submit is swiped with nothing chosen.
const String quizNoSelectionSpoken =
    'No option selected. Swipe up or down to browse, then tap to select.';

/// What the three-finger hold says on the reader.
String quizHoldSummary({
  required int questionIndex,
  required int total,
  required bool submitted,
  bool? correct,
  String? selectedLetter,
}) {
  final String status;
  if (submitted) {
    status = 'Submitted. ${correct == true ? 'Correct' : 'Incorrect'}. Swipe up to continue.';
  } else if (selectedLetter != null) {
    status = 'Option $selectedLetter selected. Swipe right to submit.';
  } else {
    status =
        'No option selected. Swipe up or down to browse, tap to select, swipe right to submit.';
  }
  return 'Quiz, question ${questionIndex + 1} of $total. $status';
}

/// One quiz in the browser's queue.
String quizBrowserUnit({
  required String title,
  required String category,
  required int questions,
  required String status,
  required int percent,
}) =>
    '$title. $category. $questions questions. $status. $percent percent complete.';

/// What the three-finger hold says on the browser.
String quizBrowserHold({
  required String currentTitle,
  required String status,
  required int done,
  required int total,
}) =>
    'Quizzes. $done of $total completed. Currently focused: $currentTitle. $status.';

/// Announced when a quiz is opened.
String quizOpenSpoken(String title) => 'Opening $title.';

/// The card button shows the status label title-cased: "Start Quiz".
String quizButtonTitle(String buttonLabel) => buttonLabel
    .split(' ')
    .map((String w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// The retry round as its own quiz: the missed questions under a review title.
LibraryQuizSet reviewSet(List<LibraryQuizQuestion> missed) => LibraryQuizSet(
      id: 'quiz_review',
      title: 'Review: Missed Questions',
      category: '',
      questions: missed,
    );
