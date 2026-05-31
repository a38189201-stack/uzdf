const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

const zones = [
  {
    name: "Международный Аэропорт Ташкент (TAS)",
    type: "RED",
    maxAltitude: 0,
    coordinates: [
      [69.2600, 41.2700],
      [69.3100, 41.2700],
      [69.3100, 41.2400],
      [69.2600, 41.2400],
      [69.2600, 41.2700]
    ]
  },
  {
    name: "Центральный Административный Район (Сквер)",
    type: "YELLOW",
    maxAltitude: 50,
    coordinates: [
      [69.2700, 41.3180],
      [69.2900, 41.3180],
      [69.2900, 41.3050],
      [69.2700, 41.3050],
      [69.2700, 41.3180]
    ]
  },
  {
    name: "Парковая Зона Анхор (Полеты разрешены)",
    type: "GREEN",
    maxAltitude: 120,
    coordinates: [
      [69.2500, 41.3350],
      [69.2700, 41.3350],
      [69.2700, 41.3250],
      [69.2500, 41.3250],
      [69.2500, 41.3350]
    ]
  }
];

async function seed() {
  // Clear existing zones to avoid duplication
  await p.zone.deleteMany({});
  for (const zone of zones) {
    await p.zone.create({
      data: {
        name: zone.name,
        type: zone.type,
        maxAltitude: zone.maxAltitude,
        coordinates: zone.coordinates
      }
    });
  }
  console.log("Airspace zones seeded successfully!");
}

seed().catch(console.error).finally(() => p.$disconnect());
