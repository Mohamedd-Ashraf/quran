<!DOCTYPE html>

<html dir="rtl" lang="ar"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<link href="https://fonts.googleapis.com/css2?family=Noto+Serif:wght@400;700;900&amp;family=Plus+Jakarta+Sans:wght@400;500;600;700&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<script id="tailwind-config">
      tailwind.config = {
        darkMode: "class",
        theme: {
          extend: {
            colors: {
              "secondary-container": "#fed65b",
              "error-container": "#ffdad6",
              "error": "#ba1a1a",
              "on-tertiary-container": "#f69f0d",
              "on-secondary-container": "#745c00",
              "tertiary-container": "#623c00",
              "on-primary": "#ffffff",
              "surface-dim": "#d9dadb",
              "on-error-container": "#93000a",
              "outline-variant": "#bfc9c3",
              "on-background": "#191c1d",
              "secondary-fixed-dim": "#e9c349",
              "primary-container": "#064e3b",
              "on-surface": "#191c1d",
              "on-secondary-fixed": "#241a00",
              "background": "#f8f9fa",
              "secondary": "#735c00",
              "surface-variant": "#e1e3e4",
              "on-error": "#ffffff",
              "primary-fixed": "#b0f0d6",
              "on-tertiary-fixed": "#2a1700",
              "surface-container": "#edeeef",
              "inverse-surface": "#2e3132",
              "on-tertiary-fixed-variant": "#653e00",
              "on-secondary": "#ffffff",
              "on-secondary-fixed-variant": "#574500",
              "on-surface-variant": "#404944",
              "inverse-on-surface": "#f0f1f2",
              "tertiary-fixed-dim": "#ffb95f",
              "outline": "#707974",
              "on-primary-container": "#80bea6",
              "primary": "#003527",
              "surface-bright": "#f8f9fa",
              "tertiary": "#442800",
              "on-tertiary": "#ffffff",
              "surface-tint": "#2b6954",
              "surface-container-highest": "#e1e3e4",
              "tertiary-fixed": "#ffddb8",
              "primary-fixed-dim": "#95d3ba",
              "surface-container-low": "#f3f4f5",
              "on-primary-fixed": "#002117",
              "on-primary-fixed-variant": "#0b513d",
              "inverse-primary": "#95d3ba",
              "surface-container-high": "#e7e8e9",
              "surface": "#f8f9fa",
              "secondary-fixed": "#ffe088",
              "surface-container-lowest": "#ffffff"
            },
            fontFamily: {
              "headline": ["Noto Serif"],
              "body": ["Plus Jakarta Sans"],
              "label": ["Plus Jakarta Sans"]
            },
            borderRadius: {"DEFAULT": "1rem", "lg": "2rem", "xl": "3rem", "full": "9999px"},
          },
        },
      }
    </script>
<style>
      .material-symbols-outlined {
        font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
      }
      body {
        font-family: 'Plus Jakarta Sans', sans-serif;
        background-color: #f8f9fa;
      }
      .font-noto-serif {
        font-family: 'Noto Serif', serif;
      }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
</head>
<body class="bg-surface text-on-surface min-h-screen pb-32">
<!-- TopAppBar -->
<header class="fixed top-0 w-full z-50 bg-emerald-50/80 backdrop-blur-xl flex items-center justify-between px-6 h-16 w-full">
<div class="flex items-center gap-4">
<button class="w-10 h-10 flex items-center justify-center rounded-full hover:bg-emerald-100/50 transition-colors">
<span class="material-symbols-outlined text-emerald-900">menu</span>
</button>
<h1 class="font-noto-serif font-black text-emerald-900 italic text-lg tracking-tight">Noor Al-Iman</h1>
</div>
<div class="w-10 h-10 rounded-full bg-emerald-200 border-2 border-white shadow-sm overflow-hidden">
<img alt="Profile" data-alt="close-up portrait of a middle-eastern man with a kind expression and neat beard in soft studio lighting" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCxsp5wxXHA7Z36J6onQPv1e3-iQ0PuNDiodG0g1W_6OvBg6l0s4c1oaCjGLnqEKTqhzeMIwIkPsviPE5tFzD4yK-8ex8DbTfwV0oLxxTa0NU8mWmM1ztXNptlLY5W2giz1TyuXlmIx7f_-3xrwEAeCmKBCYiv3kgyvb3CLhxE8UQHzjQ4UOZZwz2ZE09hNfBzN7yJdtsim3DVDe-ARtzZNztXsmnf3OQSgsZ-8W212LIFw1nK5MOAa2w34iIrU0QnW2XNDAsZ9TDYw"/>
</div>
</header>
<main class="pt-24 px-6 max-w-2xl mx-auto space-y-8">
<!-- Hero Section -->
<section class="space-y-2">
<h2 class="font-noto-serif text-3xl font-bold text-primary tracking-tight">إنشاء خطة تلاوة</h2>
<p class="text-on-surface-variant font-medium opacity-80">صمم رحلتك الروحية الخاصة مع القرآن الكريم</p>
</section>
<!-- Strategy Selection (Bento Style) -->
<section class="grid grid-cols-2 gap-4">
<div class="group relative p-6 bg-primary-container rounded-xl overflow-hidden cursor-pointer transition-all hover:scale-[1.02]">
<div class="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full -mr-16 -mt-16 blur-2xl"></div>
<div class="relative z-10 flex flex-col h-full justify-between gap-4">
<span class="material-symbols-outlined text-on-primary-container text-4xl" style="font-variation-settings: 'FILL' 1;">calendar_today</span>
<div>
<h3 class="text-white font-bold text-lg">بالأيام</h3>
<p class="text-on-primary-container text-xs opacity-80">حدد مدة الختمة بالأيام</p>
</div>
</div>
<div class="absolute bottom-4 left-4">
<span class="material-symbols-outlined text-white">check_circle</span>
</div>
</div>
<div class="group relative p-6 bg-surface-container-lowest rounded-xl border border-outline-variant/20 cursor-pointer transition-all hover:bg-emerald-50">
<div class="relative z-10 flex flex-col h-full justify-between gap-4">
<span class="material-symbols-outlined text-emerald-800/40 text-4xl">auto_stories</span>
<div>
<h3 class="text-emerald-900 font-bold text-lg">بالصفحات</h3>
<p class="text-on-surface-variant text-xs opacity-70">حدد عدد الصفحات يومياً</p>
</div>
</div>
</div>
</section>
<!-- Duration Selection -->
<section class="space-y-4">
<div class="flex items-center justify-between">
<label class="font-noto-serif text-lg font-bold text-primary">المدة الزمنية</label>
<span class="text-secondary font-bold text-sm">أيام</span>
</div>
<div class="grid grid-cols-4 gap-3">
<button class="py-3 px-2 rounded-xl bg-surface-container-high text-on-surface-variant font-bold transition-all hover:bg-emerald-100 active:scale-95">7</button>
<button class="py-3 px-2 rounded-xl bg-surface-container-high text-on-surface-variant font-bold transition-all hover:bg-emerald-100 active:scale-95">10</button>
<button class="py-3 px-2 rounded-xl bg-surface-container-high text-on-surface-variant font-bold transition-all hover:bg-emerald-100 active:scale-95">14</button>
<button class="py-3 px-2 rounded-xl bg-primary text-white font-bold shadow-lg shadow-emerald-900/20 active:scale-95">20</button>
<button class="py-3 px-2 rounded-xl bg-surface-container-high text-on-surface-variant font-bold transition-all hover:bg-emerald-100 active:scale-95">30</button>
<button class="py-3 px-2 rounded-xl bg-surface-container-high text-on-surface-variant font-bold transition-all hover:bg-emerald-100 active:scale-95">60</button>
<!-- Custom Duration Option -->
<button class="col-span-2 py-3 px-2 rounded-xl bg-surface-container-lowest border-2 border-dashed border-outline-variant/50 text-secondary font-bold flex items-center justify-center gap-2 hover:bg-amber-50 hover:border-secondary/50 transition-all active:scale-95 group">
<span class="material-symbols-outlined text-xl transition-transform group-hover:rotate-45">settings</span>
<span>مخصص</span>
</button>
</div>
<!-- Hidden by default, shown when "Custom" is active -->
<div class="hidden flex items-center bg-surface-container-lowest p-3 rounded-xl border border-primary/20 animate-in fade-in slide-in-from-top-2 duration-300">
<input class="w-full bg-transparent border-none focus:ring-0 text-primary font-bold text-center" placeholder="أدخل عدد الأيام..." type="number"/>
<span class="text-on-surface-variant text-sm font-medium px-4 border-r border-outline-variant/30">يوم</span>
</div>
</section>
<!-- Date & Time Settings -->
<div class="grid md:grid-cols-2 gap-6">
<!-- Start Date -->
<section class="p-6 bg-surface-container-lowest rounded-xl space-y-4 shadow-sm">
<div class="flex items-center gap-3">
<div class="w-10 h-10 rounded-full bg-emerald-50 flex items-center justify-center text-primary">
<span class="material-symbols-outlined">event</span>
</div>
<label class="font-bold text-primary">تاريخ البدء</label>
</div>
<div class="relative">
<input class="w-full bg-surface-container-low border-none rounded-lg p-4 text-on-surface font-medium focus:ring-2 focus:ring-primary/20 cursor-pointer" type="text" value="الإثنين، 24 أكتوبر"/>
<span class="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-outline">expand_more</span>
</div>
</section>
<!-- Daily Reminder -->
<section class="p-6 bg-surface-container-lowest rounded-xl space-y-4 shadow-sm">
<div class="flex items-center justify-between">
<div class="flex items-center gap-3">
<div class="w-10 h-10 rounded-full bg-amber-50 flex items-center justify-center text-secondary">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1;">notifications_active</span>
</div>
<label class="font-bold text-primary">تذكير يومي</label>
</div>
<div class="relative inline-flex items-center cursor-pointer">
<input checked="" class="sr-only peer" type="checkbox"/>
<div class="w-11 h-6 bg-surface-container-high rounded-full peer peer-checked:after:translate-x-[-100%] peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
</div>
</div>
<div class="relative">
<input class="w-full bg-surface-container-low border-none rounded-lg p-4 text-on-surface font-medium focus:ring-2 focus:ring-primary/20 cursor-pointer" type="time" value="05:30"/>
</div>
</section>
</div>
<!-- Summary Card -->
<section class="relative group">
<div class="absolute -inset-1 bg-gradient-to-r from-emerald-600 to-amber-600 rounded-xl blur opacity-10 group-hover:opacity-20 transition duration-1000 group-hover:duration-200"></div>
<div class="relative p-8 bg-surface-container-lowest rounded-xl flex items-center justify-between border border-outline-variant/10">
<div class="space-y-1">
<p class="text-xs font-bold text-secondary uppercase tracking-widest">ملخص الخطة</p>
<p class="text-on-surface-variant text-sm font-medium">سيتم ختم القرآن في <span class="text-primary font-bold">20 يوماً</span> بمعدل <span class="text-primary font-bold">30 صفحة</span> يومياً.</p>
</div>
<div class="hidden sm:block">
<span class="material-symbols-outlined text-5xl text-emerald-900/10">auto_awesome</span>
</div>
</div>
</section>
<!-- Primary CTA -->
<div class="pt-4">
<button class="w-full py-5 bg-gradient-to-br from-primary to-primary-container text-white font-bold rounded-xl shadow-xl shadow-emerald-900/30 hover:shadow-2xl hover:scale-[1.01] transition-all flex items-center justify-center gap-3">
<span class="material-symbols-outlined">rocket_launch</span>
                ابدأ الآن
            </button>
</div>
</main>
<!-- BottomNavBar -->
<nav class="fixed bottom-8 w-full flex justify-around items-center px-4 z-50">
<div class="bg-emerald-50/90 dark:bg-emerald-950/90 backdrop-blur-2xl flex justify-around items-center w-[90%] max-w-md rounded-[2.5rem] py-3 shadow-[0_16px_40px_rgba(0,0,0,0.08)]">
<div class="flex flex-col items-center justify-center text-emerald-800/50 dark:text-emerald-400/50 w-14 h-14 hover:text-emerald-700 dark:hover:text-emerald-200 cursor-pointer">
<span class="material-symbols-outlined">home_mini</span>
<span class="font-noto-serif text-[11px] font-medium tracking-wide">Home</span>
</div>
<div class="flex flex-col items-center justify-center bg-emerald-800 dark:bg-emerald-700 text-white dark:text-emerald-50 rounded-full w-14 h-14 shadow-lg shadow-emerald-900/20 cursor-pointer">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1;">menu_book</span>
<span class="font-noto-serif text-[11px] font-medium tracking-wide">My Wird</span>
</div>
<div class="flex flex-col items-center justify-center text-emerald-800/50 dark:text-emerald-400/50 w-14 h-14 hover:text-emerald-700 dark:hover:text-emerald-200 cursor-pointer">
<span class="material-symbols-outlined">auto_stories</span>
<span class="font-noto-serif text-[11px] font-medium tracking-wide">Library</span>
</div>
<div class="flex flex-col items-center justify-center text-emerald-800/50 dark:text-emerald-400/50 w-14 h-14 hover:text-emerald-700 dark:hover:text-emerald-200 cursor-pointer">
<span class="material-symbols-outlined">settings</span>
<span class="font-noto-serif text-[11px] font-medium tracking-wide">Settings</span>
</div>
</div>
</nav>
<!-- Decorative Pattern Background (Subtle) -->
<div class="fixed inset-0 pointer-events-none opacity-[0.03] z-[-1] overflow-hidden">
<svg height="100%" width="100%" xmlns="http://www.w3.org/2000/svg">
<pattern height="100" id="islamic-pattern" patternunits="userSpaceOnUse" width="100" x="0" y="0">
<path d="M50 0 L100 50 L50 100 L0 50 Z" fill="none" stroke="#003527" stroke-width="1"></path>
<circle cx="50" cy="50" fill="none" r="20" stroke="#003527" stroke-width="1"></circle>
</pattern>
<rect fill="url(#islamic-pattern)" height="100%" width="100%"></rect>
</svg>
</div>
</body></html>