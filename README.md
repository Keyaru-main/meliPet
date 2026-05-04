# 📦 MeliPet Repository Files

این پوشه شامل فایل‌هایی است که باید در repository GitHub شما قرار گیرد.

---

## 📋 محتویات

```
repo/
├── .github/
│   └── workflows/
│       ├── fetch.yml       # Workflow دانلود با curl
│       └── download.yml    # Workflow دانلود با Puppeteer
├── scripts/
│   ├── advanced_download.js    # اسکریپت Puppeteer پیشرفته
│   ├── fetch_utils.sh          # توابع کمکی bash
│   └── test_download.sh        # تست‌های خودکار
└── README.md               # این فایل
```

---

## 🚀 راه‌اندازی

### مرحله 1: ایجاد Repository

1. به GitHub بروید و یک repository جدید بسازید
2. نام پیشنهادی: `melli-downloads` یا `melli-proxy`
3. می‌تواند Public یا Private باشد

### مرحله 2: آپلود فایل‌ها

#### روش 1: از طریق Git

```bash
# رفتن به پوشه repo
cd repo

# مقداردهی اولیه git
git init

# اضافه کردن remote
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# اضافه کردن فایل‌ها
git add .

# commit
git commit -m "Initial commit: Add MeliPet workflows"

# push
git branch -M main
git push -u origin main
```

#### روش 2: از طریق GitHub Web

1. در repository خود، روی "Add file" کلیک کنید
2. "Upload files" را انتخاب کنید
3. تمام محتویات پوشه `repo/` را آپلود کنید
4. Commit کنید

### مرحله 3: فعال‌سازی GitHub Actions

1. به تب "Actions" در repository بروید
2. اگر پیامی برای فعال‌سازی دیدید، روی "I understand..." کلیک کنید
3. workflows باید در لیست ظاهر شوند:
   - Fetch Content
   - Download

---

## 📝 توضیح Workflows

### fetch.yml - دانلود سریع با curl

**ورودی‌ها:**
- `url`: آدرس فایل برای دانلود
- `branch_name`: نام شاخه موقت
- `file_type`: نوع محتوا (web/file)
- `output_filename`: نام فایل خروجی (اختیاری)
- `max_size`: حداکثر حجم به MB (پیش‌فرض: 100)

**خروجی:**
- فایل دانلود شده در `fetched/`
- `metadata.txt`: اطلاعات دانلود
- `filename.txt`: نام فایل

**مناسب برای:**
- دانلود مستقیم فایل‌ها
- API endpoints
- فایل‌های استاتیک
- صفحات HTML ساده

### download.yml - دانلود پیشرفته با Puppeteer

**ورودی‌ها:**
- `url`: آدرس صفحه
- `branch_name`: نام شاخه موقت
- `output_filename`: نام فایل خروجی (اختیاری)
- `wait_selector`: CSS selector برای انتظار (اختیاری)
- `click_selector`: CSS selector برای کلیک (اختیاری)
- `wait_time`: زمان انتظار به ثانیه (پیش‌فرض: 30)
- `user_agent`: User-Agent سفارشی (اختیاری)

**خروجی:**
- فایل دانلود شده در `fetched/`
- `metadata.json`: اطلاعات کامل
- `page_initial.png`: اسکرین‌شات اولیه
- `page_final.png`: اسکرین‌شات نهایی
- `found_links.json`: لینک‌های یافت شده
- `page.html`: HTML صفحه

**مناسب برای:**
- صفحات با JavaScript
- دانلودهای پیچیده (CurseForge، MediaFire، ...)
- صفحاتی که نیاز به کلیک دارند
- محتوای dynamic

---

## 🔧 سفارشی‌سازی

### اضافه کردن قابلیت به fetch.yml

```yaml
# مثال: اضافه کردن header سفارشی
- name: Fetch content
  run: |
    curl -L \
      -H "Authorization: Bearer ${{ secrets.API_TOKEN }}" \
      -o fetched/content.tmp \
      "$URL"
```

### اضافه کردن قابلیت به download.yml

```javascript
// در advanced_download.js
// مثال: اضافه کردن cookie
await page.setCookie({
  name: 'session',
  value: process.env.SESSION_COOKIE,
  domain: '.example.com'
});
```

### اضافه کردن Workflow جدید

1. فایل جدید در `.github/workflows/` بسازید
2. از الگوی fetch.yml یا download.yml استفاده کنید
3. در `internal/github/fetcher.go` متد جدید اضافه کنید
4. در `cmd/mlifetch/main.go` command جدید اضافه کنید

---

## 🔒 امنیت

### Secrets

اگر نیاز به token یا credential دارید:

1. به Settings → Secrets and variables → Actions بروید
2. "New repository secret" را بزنید
3. نام و مقدار را وارد کنید
4. در workflow از آن استفاده کنید:

```yaml
env:
  API_TOKEN: ${{ secrets.API_TOKEN }}
```

### محدودیت دسترسی

برای repository های Private:
- فقط شما دسترسی دارید
- workflows فقط توسط شما trigger می‌شوند

برای repository های Public:
- همه می‌توانند ببینند
- فقط شما می‌توانید workflow trigger کنید

---

## 📊 مانیتورینگ

### مشاهده لاگ‌ها

1. به تب "Actions" بروید
2. workflow run مورد نظر را انتخاب کنید
3. روی job کلیک کنید
4. لاگ‌ها را ببینید

### دیباگ

برای دیباگ بهتر، در workflow اضافه کنید:

```yaml
- name: Debug info
  run: |
    echo "URL: ${{ github.event.inputs.url }}"
    echo "Branch: ${{ github.event.inputs.branch_name }}"
    ls -la fetched/
```

---

## 🧹 نگهداری

### پاکسازی شاخه‌های قدیمی

```bash
# با mlifetch
mlifetch clean

# یا دستی در GitHub
# Settings → Branches → Delete old branches
```

### بررسی فضای استفاده شده

```bash
# در repository
du -sh .git
```

### محدودیت‌های GitHub Actions

- **زمان اجرا**: 6 ساعت در هر job
- **فضای دیسک**: 14 GB
- **حافظه**: 7 GB
- **تعداد workflow**: 1000 در ساعت (برای Free plan)

---

## 🆘 عیب‌یابی

### Workflow اجرا نمی‌شود

- بررسی کنید Actions فعال باشد
- بررسی کنید syntax workflow صحیح باشد
- لاگ‌ها را بررسی کنید

### دانلود ناموفق

- URL را بررسی کنید
- timeout را افزایش دهید
- selector ها را چک کنید (برای download.yml)

### شاخه ایجاد نمی‌شود

- بررسی کنید GITHUB_TOKEN دسترسی write داشته باشد
- لاگ workflow را ببینید
- بررسی کنید commit موفق بوده باشد

---

## 📚 منابع

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Puppeteer Documentation](https://pptr.dev/)
- [curl Documentation](https://curl.se/docs/)

---

## 🤝 مشارکت

برای بهبود workflows:

1. تغییرات را در پوشه `repo/` اعمال کنید
2. تست کنید
3. Pull Request بفرستید

---

<div align="center">

**سوال دارید؟ [Issue باز کنید](https://github.com/YOUR_USERNAME/melli_pet/issues)**

</div>
