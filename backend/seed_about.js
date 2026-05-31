const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

const data = [
  {
    key: "who_we_are",
    titleRu: "Кто мы и чем занимаемся",
    titleUz: "Biz kimmiz va nima qilamiz",
    titleEn: "Who We Are & What We Do",
    descRu: "Мы — команда авиационных инженеров, разработчиков и энтузиастов БПЛА. Наша цель — сделать полеты на дронах в Узбекистане безопасными, простыми и полностью легальными для каждого пилота.",
    descUz: "Biz aviatsiya muhandislari, dasturchilar va BPLA ishqibozlari jamoasimiz. Maqsadimiz — O'zbekistonda dron parvozlarini har bir uchuvchi uchun xavfsiz, oson va to'liq qonuniy qilishdir.",
    descEn: "We are a team of aviation engineers, developers, and UAV enthusiasts. Our goal is to make drone flights in Uzbekistan safe, simple, and fully legal for every pilot.",
    imageUrl: "/img/drone_tashkent.png",
    mapIframe: "",
    order: 1
  },
  {
    key: "history",
    titleRu: "История создания",
    titleUz: "Yaratilish tarixi",
    titleEn: "Our Story",
    descRu: "Проект SkyCheck зародился в 2024 году, когда мы столкнулись со сложностями согласования воздушных зон. Мы объединили усилия с экспертами отрасли, чтобы создать единую платформу с интерактивной картой и обучением.",
    descUz: "SkyCheck loyihasi 2024-yilda havo zonalarini muvofiqlashtirish qiyinchiliklariga duch kelganimizda paydo bo'lgan. Biz interaktiv xarita va o'qitish bilan yagona platforma yaratish XML ekspertlari bilan kuchlarni birlashtirdik.",
    descEn: "The SkyCheck project was born in 2024 when we faced difficulties in coordinating airspace zones. We joined forces with industry experts to create a single platform featuring an interactive map and training courses.",
    imageUrl: "/img/drone_tech.png",
    mapIframe: "",
    order: 2
  },
  {
    key: "office",
    titleRu: "Наш офис в Ташкенте",
    titleUz: "Toshkentdagi offisimiz",
    titleEn: "Our Tashkent Office",
    descRu: "Наш главный офис расположен в центре столицы. Мы всегда рады гостям, пилотам и партнерам для обсуждения вопросов развития индустрии беспилотников. Адрес: г. Ташкент, проспект Амира Темура, 107Б.",
    descUz: "Bosh offisimiz poytaxt markazida joylashgan. Dronlar sanoatini rivojlantirish masalalarini muhokama qilish uchun mehmonlar, uchuvchilar va hamkorlarni doimo kutib olishdan xursandmiz. Manzil: Toshkent sh., Amir Temur shoh ko'chasi, 107B.",
    descEn: "Our main office is located in the center of the capital. We are always happy to welcome guests, pilots, and partners to discuss the development of the drone industry. Address: 107B Amir Temur Ave, Tashkent.",
    imageUrl: "",
    mapIframe: "https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d2995.666998909886!2d69.28189871182285!3d41.33785469910403!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x38ae8b51e06fa5bb%3A0xf63980df96a798a7!2s107%20Amir%20Temur%20Avenue%2C%20Tashkent!5e0!3m2!1sen!2suz!4v1716616000000!5m2!1sen!2suz",
    order: 3
  },
  {
    key: "license",
    titleRu: "Лицензия и соответствие",
    titleUz: "Litsenziya va muvofiqlik",
    titleEn: "License & Compliance",
    descRu: "Сервис работает в строгом соответствии с воздушным кодексом и правилами использования БПЛА в Республике Узбекистан. Лицензия № БПЛА-2024-089 от Агентства гражданской авиации.",
    descUz: "Xizmat O'zbekiston Respublikasi havo kodeksi va BPLA-dan foydalanish qoidalariga qat'iy muvofiq ishlaydi. Fuqaro aviatsiyasi agentligining № BPLA-2024-089 litsenziyasi.",
    descEn: "The service operates in strict compliance with the aviation code and UAV regulation rules in the Republic of Uzbekistan. License No. UAV-2024-089 from the Civil Aviation Agency.",
    imageUrl: "/img/drone_license.png",
    mapIframe: "",
    order: 4
  }
];

async function main() {
  for (const item of data) {
    await p.aboutSection.upsert({
      where: { key: item.key },
      update: item,
      create: item
    });
  }
  console.log('AboutSections seeded successfully.');
}

main()
  .catch(e => console.error(e))
  .finally(() => p.$disconnect());
