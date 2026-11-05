import 'library.dart';

/// The lessons that ship inside the app, ported from Resonant's LessonData.
/// Chat answers from these when the AI server cannot be used, and Lessons
/// reads them aloud. Every word is the old text, unchanged.

const _photosynthesis = LibraryLesson(
  id: "lesson_photosynthesis",
  title: "Introduction to Photosynthesis",
  sections: [
    LibrarySection(
      id: "s1",
      title: "What is photosynthesis?",
      units: [
        LibraryUnit(id: "s1u1", text: "Photosynthesis is the process plants use to turn sunlight into energy."),
        LibraryUnit(id: "s1u2", text: "They capture light in their leaves and use it to build the sugars they need to grow."),
        LibraryUnit(id: "s1u3", text: "It's the reason plants are green: the pigment that captures light, chlorophyll, gives them their color."),
      ],
      keywords: ["define", "definition", "meaning", "mean", "overview", "intro", "basics", "beginner"],
    ),
    LibrarySection(
      id: "s2",
      title: "What plants need",
      units: [
        LibraryUnit(id: "s2u1", text: "Photosynthesis needs three ingredients: sunlight, water, and carbon dioxide."),
        LibraryUnit(id: "s2u2", text: "Roots draw water up from the soil, and leaves pull carbon dioxide in from the air."),
        LibraryUnit(id: "s2u3", text: "Without any one of the three, the process stops."),
      ],
      keywords: ["need", "needs", "require", "requirement", "requires", "ingredient", "ingredients", "sunlight", "water", "carbon", "dioxide"],
    ),
    LibrarySection(
      id: "s3",
      title: "The process",
      units: [
        LibraryUnit(id: "s3u1", text: "Chlorophyll in the leaf absorbs sunlight.", stepTitle: "Catch the light"),
        LibraryUnit(id: "s3u2", text: "That energy helps turn water and carbon dioxide into sugar.", stepTitle: "Make food"),
        LibraryUnit(id: "s3u3", text: "The plant uses the sugar and sends oxygen into the air.", stepTitle: "Grow and release oxygen"),
      ],
      keywords: ["work", "works", "process", "step", "steps", "procedure", "chlorophyll", "glucose", "oxygen", "reaction", "implement"],
    ),
    LibrarySection(
      id: "s4",
      title: "Example",
      units: [
        LibraryUnit(id: "s4u1", text: "Picture a leaf sitting in bright sunlight for a few hours."),
        LibraryUnit(id: "s4u2", text: "It draws in carbon dioxide and pulls water up from the roots."),
        LibraryUnit(id: "s4u3", text: "By the end of the day it has produced sugar to fuel the plant's growth, and released oxygen into the air around it."),
      ],
      keywords: ["example", "instance", "demonstrate", "demo", "sample", "illustrate", "show", "leaf"],
    ),
    LibrarySection(
      id: "s5",
      title: "Key takeaway",
      units: [
        LibraryUnit(id: "s5u1", text: "Photosynthesis turns sunlight, water, and carbon dioxide into sugar and oxygen."),
        LibraryUnit(id: "s5u2", text: "Plants use the sugar as fuel for growth."),
        LibraryUnit(id: "s5u3", text: "The oxygen they release along the way is the same oxygen most living things breathe."),
      ],
      keywords: ["summary", "summarize", "summarise", "recap", "takeaway", "remember", "important", "conclusion", "key", "main"],
    ),
  ],
);

const _cells = LibraryLesson(
  id: "lesson_cells",
  title: "Cells and their parts",
  sections: [
    LibrarySection(
      id: "s1",
      title: "What is a cell?",
      units: [
        LibraryUnit(id: "s1u1", text: "A cell is the smallest unit of life. Every living thing is made of cells."),
        LibraryUnit(id: "s1u2", text: "Some organisms, like bacteria, consist of just a single cell. Others, like humans, have trillions."),
        LibraryUnit(id: "s1u3", text: "Despite their tiny size, cells carry out all the processes needed to stay alive."),
      ],
      keywords: ["define", "definition", "meaning", "mean", "overview", "intro", "basics", "beginner", "cell"],
    ),
    LibrarySection(
      id: "s2",
      title: "The cell membrane",
      units: [
        LibraryUnit(id: "s2u1", text: "Every cell is wrapped in a thin, flexible layer called the cell membrane."),
        LibraryUnit(id: "s2u2", text: "The membrane acts like a gatekeeper, letting useful substances in and pushing waste out."),
        LibraryUnit(id: "s2u3", text: "It is selectively permeable, meaning it allows some things through but not others."),
      ],
      keywords: ["membrane", "wall", "boundary", "gatekeeper", "permeable", "selectively"],
    ),
    LibrarySection(
      id: "s3",
      title: "Key organelles",
      units: [
        LibraryUnit(id: "s3u1", text: "The nucleus is the control centre. It holds the cell's DNA and directs everything the cell does."),
        LibraryUnit(id: "s3u2", text: "Mitochondria are the powerhouses. They convert nutrients into the energy the cell uses."),
        LibraryUnit(id: "s3u3", text: "Ribosomes build proteins by reading the instructions stored in DNA."),
        LibraryUnit(id: "s3u4", text: "Plant cells also have chloroplasts, which carry out photosynthesis, and a rigid cell wall for extra support."),
      ],
      keywords: ["nucleus", "mitochondria", "ribosome", "chloroplast", "organelle", "organelles", "part", "parts", "structure", "structures"],
    ),
    LibrarySection(
      id: "s4",
      title: "Example",
      units: [
        LibraryUnit(id: "s4u1", text: "Think of a cell as a tiny factory."),
        LibraryUnit(id: "s4u2", text: "The nucleus is the manager giving orders, the mitochondria are the generators supplying power, and the ribosomes are the workers on the assembly line building products."),
        LibraryUnit(id: "s4u3", text: "The cell membrane is the factory wall, controlling what comes in and goes out."),
      ],
      keywords: ["example", "instance", "demonstrate", "demo", "sample", "illustrate", "show", "factory"],
    ),
    LibrarySection(
      id: "s5",
      title: "Key takeaway",
      units: [
        LibraryUnit(id: "s5u1", text: "Cells are the building blocks of all life."),
        LibraryUnit(id: "s5u2", text: "Each cell has a membrane, a nucleus, and specialised organelles that keep it running."),
        LibraryUnit(id: "s5u3", text: "Plant and animal cells share most parts, but plant cells also have chloroplasts and a cell wall."),
      ],
      keywords: ["summary", "summarize", "summarise", "recap", "takeaway", "remember", "important", "conclusion", "key", "main"],
    ),
  ],
);

const _ecosystems = LibraryLesson(
  id: "lesson_ecosystems",
  title: "Energy in ecosystems",
  sections: [
    LibrarySection(
      id: "s1",
      title: "What is an ecosystem?",
      units: [
        LibraryUnit(id: "s1u1", text: "An ecosystem is all the living things in an area, together with the non-living environment they depend on."),
        LibraryUnit(id: "s1u2", text: "A forest, a pond, and a coral reef are all ecosystems — each one a web of organisms exchanging energy and matter."),
        LibraryUnit(id: "s1u3", text: "Energy flows through an ecosystem in one direction: from the sun, through plants, and into animals."),
      ],
      keywords: ["define", "definition", "meaning", "mean", "overview", "intro", "basics", "beginner", "ecosystem"],
    ),
    LibrarySection(
      id: "s2",
      title: "Producers and consumers",
      units: [
        LibraryUnit(id: "s2u1", text: "Producers are organisms that make their own food, almost always through photosynthesis. Plants and algae are producers."),
        LibraryUnit(id: "s2u2", text: "Consumers eat other organisms to get energy. Herbivores eat plants, carnivores eat animals, and omnivores eat both."),
        LibraryUnit(id: "s2u3", text: "Decomposers, like fungi and bacteria, break down dead matter and return nutrients to the soil."),
      ],
      keywords: ["producer", "producers", "consumer", "consumers", "herbivore", "carnivore", "omnivore", "decomposer", "decomposers"],
    ),
    LibrarySection(
      id: "s3",
      title: "Food chains and the 10 percent rule",
      units: [
        LibraryUnit(id: "s3u1", text: "A food chain shows the order in which energy passes from one organism to the next: grass to rabbit to fox, for example."),
        LibraryUnit(id: "s3u2", text: "At each step, roughly 90 percent of the energy is lost as heat. Only about 10 percent passes to the next level."),
        LibraryUnit(id: "s3u3", text: "That is why food chains rarely have more than four or five links — there simply isn't enough energy left beyond that point."),
      ],
      keywords: ["food chain", "chain", "trophic", "level", "10 percent", "ten percent", "energy loss", "transfer", "step", "steps"],
    ),
    LibrarySection(
      id: "s4",
      title: "Example",
      units: [
        LibraryUnit(id: "s4u1", text: "Imagine a meadow. Grasses capture sunlight and store energy in their leaves."),
        LibraryUnit(id: "s4u2", text: "A rabbit eats the grass, getting about 10 percent of that stored energy."),
        LibraryUnit(id: "s4u3", text: "A fox eats the rabbit, getting about 10 percent of the rabbit's energy — just 1 percent of what the grass originally held."),
        LibraryUnit(id: "s4u4", text: "When the fox dies, decomposers break its body down and return nutrients to the soil so the grass can grow again."),
      ],
      keywords: ["example", "instance", "demonstrate", "demo", "sample", "illustrate", "show", "meadow", "rabbit", "fox"],
    ),
    LibrarySection(
      id: "s5",
      title: "Key takeaway",
      units: [
        LibraryUnit(id: "s5u1", text: "Energy enters ecosystems through producers and flows to consumers at each step of a food chain."),
        LibraryUnit(id: "s5u2", text: "About 90 percent is lost as heat at each transfer, so higher levels have far less energy available."),
        LibraryUnit(id: "s5u3", text: "Decomposers close the loop by returning nutrients to the soil."),
      ],
      keywords: ["summary", "summarize", "summarise", "recap", "takeaway", "remember", "important", "conclusion", "key", "main"],
    ),
  ],
);

const _plantAdaptations = LibraryLesson(
  id: "lesson_plant_adaptations",
  title: "Plant adaptations",
  sections: [
    LibrarySection(
      id: "s1",
      title: "What is an adaptation?",
      units: [
        LibraryUnit(id: "s1u1", text: "An adaptation is a feature that helps an organism survive in its environment."),
        LibraryUnit(id: "s1u2", text: "Adaptations develop over many generations through natural selection: individuals with helpful traits are more likely to survive and pass those traits on."),
        LibraryUnit(id: "s1u3", text: "Plants have evolved a wide range of adaptations to cope with heat, cold, drought, and limited light."),
      ],
      keywords: ["define", "definition", "meaning", "mean", "overview", "intro", "basics", "beginner", "adaptation"],
    ),
    LibrarySection(
      id: "s2",
      title: "Desert adaptations",
      units: [
        LibraryUnit(id: "s2u1", text: "Cacti store water in their thick, fleshy stems and are coated in wax to slow evaporation."),
        LibraryUnit(id: "s2u2", text: "Their leaves have evolved into spines, which reduces water loss and deters animals from eating the plant."),
        LibraryUnit(id: "s2u3", text: "Some desert plants have very deep roots to reach underground water, while others spread shallow roots wide to catch any brief rainfall."),
      ],
      keywords: ["desert", "cactus", "cacti", "drought", "water storage", "spines", "wax", "dry", "arid"],
    ),
    LibrarySection(
      id: "s3",
      title: "Cold climate adaptations",
      units: [
        LibraryUnit(id: "s3u1", text: "Conifers like pine trees have needle-shaped leaves, which lose very little water in cold, dry air."),
        LibraryUnit(id: "s3u2", text: "Their waxy coating also prevents freezing damage, and their downward-sloping branches shed heavy snow before it can break them."),
        LibraryUnit(id: "s3u3", text: "Some tundra plants grow low to the ground to avoid cold winds, and have darker pigments to absorb more heat from the weak sunlight."),
      ],
      keywords: ["cold", "conifer", "pine", "needle", "tundra", "freeze", "frost", "snow", "arctic", "alpine"],
    ),
    LibrarySection(
      id: "s4",
      title: "Aquatic adaptations",
      units: [
        LibraryUnit(id: "s4u1", text: "Water lilies have flat, buoyant leaves filled with air pockets to stay on the surface where sunlight reaches."),
        LibraryUnit(id: "s4u2", text: "Aquatic plants often have flexible stems that bend with currents rather than break."),
        LibraryUnit(id: "s4u3", text: "Many lack the thick waxy coating of land plants because they don't need to prevent water loss."),
      ],
      keywords: ["aquatic", "water", "pond", "lake", "water lily", "floating", "buoyant", "river", "stream"],
    ),
    LibrarySection(
      id: "s5",
      title: "Key takeaway",
      units: [
        LibraryUnit(id: "s5u1", text: "Plant adaptations are features shaped by natural selection to help a plant survive its specific environment."),
        LibraryUnit(id: "s5u2", text: "Desert plants conserve water, cold-climate plants resist freezing, and aquatic plants are built to float and flex."),
        LibraryUnit(id: "s5u3", text: "The same basic needs, water, light, and nutrients, are met in very different ways depending on where a plant lives."),
      ],
      keywords: ["summary", "summarize", "summarise", "recap", "takeaway", "remember", "important", "conclusion", "key", "main"],
    ),
  ],
);

const _binarySearch = LibraryLesson(
  id: "lesson_binary_search",
  title: "Introduction to Binary Search",
  sections: [
    LibrarySection(
      id: "s1",
      title: "What is binary search?",
      units: [
        LibraryUnit(id: "s1u1", text: "Binary search is a method for finding an item in a sorted list very quickly."),
        LibraryUnit(id: "s1u2", text: "Instead of checking every item one by one, it repeatedly cuts the search area in half."),
        LibraryUnit(id: "s1u3", text: "This makes it dramatically faster than a simple linear scan for large lists."),
      ],
      keywords: ["define", "definition", "meaning", "mean", "overview", "intro", "basics", "beginner"],
    ),
    LibrarySection(
      id: "s2",
      title: "Why sorting matters",
      units: [
        LibraryUnit(id: "s2u1", text: "Binary search only works if the list is already sorted."),
        LibraryUnit(id: "s2u2", text: "Because the algorithm decides which half to search based on order, an unsorted list breaks that logic entirely."),
        LibraryUnit(id: "s2u3", text: "Sorting is the price you pay once, so that every future search can be fast."),
      ],
      keywords: ["sorted", "sort", "sorting", "unsorted", "order", "ordered", "require", "requirement", "precondition", "matter", "matters"],
    ),
    LibrarySection(
      id: "s3",
      title: "The algorithm",
      units: [
        LibraryUnit(id: "s3u1", text: "Start by looking at the middle item of the list."),
        LibraryUnit(id: "s3u2", text: "If it matches what you're looking for, you're done."),
        LibraryUnit(id: "s3u3", text: "If your target is smaller, repeat the search in the left half."),
        LibraryUnit(id: "s3u4", text: "If your target is larger, repeat the search in the right half."),
        LibraryUnit(id: "s3u5", text: "Keep cutting the remaining range in half until you find the item or run out of items."),
      ],
      keywords: ["work", "works", "algorithm", "step", "steps", "process", "procedure", "middle", "half", "halve", "implement"],
    ),
    LibrarySection(
      id: "s4",
      title: "Example",
      units: [
        LibraryUnit(id: "s4u1", text: "Imagine searching for the number seven in the sorted list: one, three, five, seven, nine, eleven."),
        LibraryUnit(id: "s4u2", text: "The middle item is seven. It matches immediately, so the search ends in a single step."),
        LibraryUnit(id: "s4u3", text: "With a linear scan, you might have checked four items before finding it."),
      ],
      keywords: ["example", "instance", "demonstrate", "demo", "sample", "illustrate", "show", "seven"],
    ),
    LibrarySection(
      id: "s5",
      title: "Key takeaway",
      units: [
        LibraryUnit(id: "s5u1", text: "Binary search requires a sorted array."),
        LibraryUnit(id: "s5u2", text: "Each step eliminates half of the remaining possibilities."),
        LibraryUnit(id: "s5u3", text: "That's what makes it so much faster than checking every item one at a time."),
      ],
      keywords: ["summary", "summarize", "summarise", "recap", "takeaway", "remember", "important", "conclusion", "key", "main"],
    ),
  ],
);

const _plateTectonics = LibraryLesson(
  id: "lesson_plate_tectonics",
  title: "Introduction to Plate Tectonics",
  sections: [
    LibrarySection(
      id: "s1",
      title: "What is plate tectonics?",
      units: [
        LibraryUnit(id: "s1u1", text: "Plate tectonics is the idea that Earth's outer shell is broken into large pieces called plates."),
        LibraryUnit(id: "s1u2", text: "These plates carry the continents and ocean floors, and they are always moving, just very slowly."),
        LibraryUnit(id: "s1u3", text: "Most plates drift only a few centimeters a year, about as fast as fingernails grow."),
      ],
      keywords: ["define", "definition", "meaning", "mean", "overview", "intro", "basics", "beginner", "plate", "plates"],
    ),
    LibrarySection(
      id: "s2",
      title: "Why the plates move",
      units: [
        LibraryUnit(id: "s2u1", text: "Deep inside the Earth, heat drives slow currents in the hot rock of the mantle."),
        LibraryUnit(id: "s2u2", text: "Those currents drag the plates floating above them along, the way a slow current drags a raft."),
        LibraryUnit(id: "s2u3", text: "Over millions of years, that steady drag reshapes where the continents sit."),
      ],
      keywords: ["move", "moves", "moving", "cause", "causes", "mantle", "convection", "current", "currents", "heat", "drive", "driver"],
    ),
    LibrarySection(
      id: "s3",
      title: "The three types of boundaries",
      units: [
        LibraryUnit(id: "s3u1", text: "Where two plates pull apart, new crust forms in the gap; that's a divergent boundary."),
        LibraryUnit(id: "s3u2", text: "Where two plates crash together, one may be pushed under the other, or both may buckle upward; that's a convergent boundary."),
        LibraryUnit(id: "s3u3", text: "Where two plates slide past each other sideways, that's a transform boundary."),
        LibraryUnit(id: "s3u4", text: "Most earthquakes and volcanoes happen right along these boundaries."),
      ],
      keywords: ["boundary", "boundaries", "type", "types", "divergent", "convergent", "transform", "earthquake", "volcano", "step", "steps"],
    ),
    LibrarySection(
      id: "s4",
      title: "Example",
      units: [
        LibraryUnit(id: "s4u1", text: "The Himalayas are still rising today because the plate carrying India is pushing into the plate carrying Asia."),
        LibraryUnit(id: "s4u2", text: "That collision is a convergent boundary, and it has been crumpling the land upward for millions of years."),
        LibraryUnit(id: "s4u3", text: "California's San Andreas Fault, by contrast, is a transform boundary where plates grind past each other sideways."),
      ],
      keywords: ["example", "instance", "demonstrate", "demo", "sample", "illustrate", "show", "himalayas"],
    ),
    LibrarySection(
      id: "s5",
      title: "Key takeaway",
      units: [
        LibraryUnit(id: "s5u1", text: "Earth's crust is broken into plates that drift on slow currents in the mantle."),
        LibraryUnit(id: "s5u2", text: "Where those plates meet, they pull apart, collide, or slide past one another."),
        LibraryUnit(id: "s5u3", text: "That motion, over millions of years, builds mountains and shapes the map of the continents."),
      ],
      keywords: ["summary", "summarize", "summarise", "recap", "takeaway", "remember", "important", "conclusion", "key", "main"],
    ),
  ],
);

/// The shipped library, in the old reading order.
const builtInLessons = [
  _photosynthesis,
  _cells,
  _ecosystems,
  _plantAdaptations,
  _binarySearch,
  _plateTectonics,
];
