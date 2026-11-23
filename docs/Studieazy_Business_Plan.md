# BUSINESS PLAN
# Studieazy

Kurt Daryl R, De Mesa  
Course and Section: BSIT-41A2 Instructor Name: Jeremy Lloyd Claveria  
Official Date: September 2026  

---

## 1. Executive Summary

**Studieazy** is an innovative, educational technology-driven study platform designed to help students, licensure examinees, and self-directed learners study more effectively and achieve academic retention with ease. Built with **Flutter**, **Firebase**, and **Google Gemini Generative AI**, Studieazy allows learners to convert dense lecture notes, slide presentations, and review modules (PDF, DOCX, TXT) into interactive quizzes and flashcards in seconds.

The platform eliminates tedious hours spent manually creating reviewers, addressing cramming anxiety and passive reading habits through scientifically proven active recall and spaced repetition. Studieazy offers a responsive mobile and web user experience featuring animated flashcards, multiple-choice quizzes, offline review capabilities, and personal study analytics, paired with an administrative management dashboard.

Studieazy operates nationwide across the Philippines. The business model combines a **Freemium AI Generation Pass model** featuring highly affordable, student-tailored passes (Daily, Weekly, and Monthly tiers with strict expiration rules and AI generation quotas) alongside institutional B2B licensing opportunities for schools and review centers.

---

## 2. Business Description

| Item | Description |
| :--- | :--- |
| **Business Name** | **Studieazy** |
| **Business Type** | Educational Technology (EdTech) / Mobile & Web Study Platform |
| **Business Model** | Freemium B2C (Micro-Subscriptions) & B2B (Institutional Reviewer Partnerships) |
| **Scope / Location** | Nationwide (Available to all students and educational institutions across the Philippines) |
| **Mission** | To provide accessible, intelligent, and affordable digital study tools that empower students to master any subject with ease and confidence. |
| **Vision** | To become the premier AI-powered learning companion and digital review standard for students and board examinees in the Philippines and Southeast Asia. |

---

## 3. Problem Statement

Filipino students and professional board exam reviewees frequently struggle with academic preparation and information retention due to several systemic issues:

* **Passive Reading and Cramming:** Many students rely on passive rereading and static highlighting of thick handouts, leading to rapid memory decay and poor exam performance.
* **Time-Consuming Manual Reviewer Creation:** Manually drafting practice questions and flashcard sets from lengthy modules, syllabi, or slides consumes valuable hours that could be dedicated to active learning.
* **Fragmented Study Materials:** Review materials, PDFs, and notes are scattered haphazardly across Google Drives, Messenger chats, and physical photocopies, lacking structured progress tracking.
* **High Cost of Existing Foreign Platforms:** Established global applications (e.g., Quizlet, Brainscape) lock advanced features, offline access, and AI behind costly recurring dollar subscriptions (₱1,500–₱2,500/year) that exceed typical student allowances.

Studieazy directly solves these pain points by offering an accessible, localized, and automated study system.

---

## 4. Proposed Solution

* **Document-to-Quiz AI Automation:** Upload modules in PDF, DOCX, or text format to instantly generate structured multiple-choice questions and flashcard decks using Google Gemini.
* **Dual Interactive Study Modes:**
  * *Flashcard Mode:* Flip-card animations with mastery tracking (Known vs. Still Learning).
  * *Quiz Mode:* Timed multiple-choice assessments with immediate answer validation and final score reports.
* **Offline Study Accessibility:** Local data persistence via Hive caching, allowing students to study without an active data connection.
* **Personal Study Analytics:** Track mastery levels, study frequency, total quizzes completed, and average scores.
* **Administrative Operations Portal:** Centralized dashboard for user accounts, role-based privileges, support tickets, and system error logs.

---

## 5. Product and Service

### Student Mobile & Web Application
* **Authentication:** Secure sign-up/login with email and Google credentials backed by Firebase Authentication.
* **Home Dashboard:** Quick overview of active study decks, recent scores, study streaks, and study shortcuts.
* **AI Quiz Generator:** Document upload engine with selectable question quantity, topic prompting, and draft question editing before publishing.
* **Manual Quiz Creator:** Custom question builder supporting both multiple-choice options and flashcard front/back formats.
* **Search & Filter:** Real-time search across saved decks and categorization by academic subject.
* **Profile & Settings:** Personal information management, avatar customization, and session data synchronization.
* **Support Ticketing:** In-app form allowing students to submit bug reports and feature requests directly to support.

### Administrator Dashboard
* **User Management:** Monitor active and registered user accounts, track growth metrics, and manage user statuses.
* **Role & Permission Management:** Grant administrative, moderator, or viewer privileges securely.
* **Support Ticket System:** View, prioritize, respond to, and resolve student support inquiries.
* **Error & Diagnostic Monitoring:** Track real-time application exceptions, AI API parsing failures, and sync errors.
* **System Backup Management:** Oversee database health and trigger snapshots.

---

## 6. Unique Selling Proposition

Studieazy differentiates itself by pairing **automated document-to-quiz AI generation** with **hyper-affordable, flexible micro-passes** customized for the Filipino student budget.

* **Customer Value Proposition:** *"Convert your heaviest lecture modules and slide decks into interactive quizzes in seconds, and study anytime, anywhere—even offline."*
* **Educator & Institutional Value Proposition:** *"Digitize your review curriculum into interactive formative assessments with zero development overhead and rich learner analytics."*

---

## 7. Target Market

| Category | Primary Customer Profile |
| :--- | :--- |
| **Target Age** | 16–28 years old |
| **Geographic Scope** | Nationwide (Students across major university belts and provincial schools in the Philippines) |
| **Target Segments** | Senior High School (STEM, HUMSS, ABM), College Undergraduates, and Professional Licensure Examinees (BLEPT, Nursing, Civil Service, CPA, Engineering) |
| **Income / Allowance** | Low to Middle student allowance (₱100–₱800/week) |
| **Device & Technology** | Android smartphones, Windows/Mac laptops, iPhones, and tablets with intermittent mobile data |
| **User Behavior** | Studies during commutes, engages in intensive review cycles during midterms/finals/board exams, active on GCash/Maya |
| **Primary Need** | Rapid reviewer generation, effective self-assessment tools, and reliable offline study support |

---

## 8. Market Analysis

**Industry:** Educational Technology (EdTech) + Generative AI + Mobile & Web Applications

With over 3.5 million enrolled college students and hundreds of thousands of annual professional board examinees in the Philippines, demand for digitized review materials is at an all-time high.

**Potential Competitors:**
* **Quizlet:** High global brand recognition, but locks flashcard study modes and AI utilities behind an expensive yearly paywall (~₱1,800+/year).
* **Anki:** Highly powerful spaced repetition algorithm, but burdened by a steep technical learning curve and an outdated, unappealing interface.
* **Studocu / Scribd:** Abundant static note uploads, but completely lacks interactive testing, card drills, and automated quiz creation.
* **Traditional Physical Reviewers:** Bulky, static, non-interactive, and expensive to reprint.

**Competitive Advantage of Studieazy:** Native document AI parsing (PDF/DOCX to Quiz), student-friendly micro-pricing via e-wallets, clean modern Flutter interface, and offline-first mobile readiness.

---

## 9. SWOT Analysis

| Strengths | Weaknesses |
| :--- | :--- |
| • Automated document-to-quiz generation via Google Gemini AI<br>• Cross-platform Flutter engine (single codebase for Web & Android)<br>• Full offline study capability with local Hive caching<br>• Flexible micro-subscription passes (₱20/day, ₱100/week, ₱250/month)<br>• Built-in administrative dashboard and support ticket workflow | • New brand with zero initial market awareness<br>• Dependent on third-party cloud infrastructure (Firebase, Google AI)<br>• Limited initial capital for large-scale marketing blitzes<br>• Variable AI API token costs based on document length |
| **Opportunities** | **Threats** |
| • Nationwide student adoption of mobile e-wallets (GCash and Maya)<br>• High recurring demand during midterm, final, and board exam seasons<br>• Partnerships with university student councils and academic clubs<br>• B2B licensing for commercial licensure review centers<br>• Expansion into community-shared verified study decks | • Established international competitors adding local payment options<br>• Seasonal churn during academic vacation breaks<br>• Changes in AI API pricing or token rate limits from providers<br>• Users attempting to upload poor quality or corrupted documents |

---

## 10. Marketing Plan

### Social Media & "StudyTok" Campaign
Produce short, highly relatable demonstration videos on TikTok, Facebook Reels, and Instagram highlighting real academic scenarios (e.g., *"How to turn a 40-page lecture handout into a review quiz 1 hour before class"*).

### Campus Ambassador & Student Leader Outreach
Partner with student leaders, college organizations, and honor societies across universities nationwide. Ambassadors receive free monthly passes in exchange for organizing group study sessions using Studieazy.

### Review Center & Academic Alliances
Approach licensure review centers (BLEPT, Nursing, Civil Service) to provide enrollees with digital practice decks powered by Studieazy.

### Gamified Referral Program
Existing users who invite three classmates unlock 15 bonus AI document generations or a 3-day premium access pass for free.

---

## 11. Revenue Model

Studieazy operates on a **Freemium AI Generation Pass Model** designed to accommodate the budget realities and study cycles of Filipino students. Core study utilities—such as manual quiz creation, flashcard drilling, and quiz taking—are 100% free forever. Students pay specifically for automated **AI Quiz Generation Passes**, structured by duration and maximum generation quota:

| Pass Tier | Price (PHP) | AI Generation Cap | Duration & Expiration Policy |
| :--- | :--- | :--- | :--- |
| **Free Starter** | ₱0 (Free forever) | 3 Free AI Generations | Trial quota for new accounts. Manual quiz building and flashcard/quiz study modes remain unlimited and free. |
| **Daily Pass** | **₱20 / 1 day** | **Max 20 Quizzes** | Valid for exactly 24 hours. *Strict Expiration Rule:* The pass expires after 1 day; any unused generations from the 20-quiz quota are forfeited. (Not full access). |
| **Weekly Pass** | **₱100 / 7 days** | **Max 50 Quizzes** | Valid for 7 days. *Strict Expiration Rule:* The pass expires after 7 days; any unused generations from the 50-quiz quota are forfeited once the 7 days elapse. |
| **Monthly Pass** | **₱250 / 1 month** | **Max 250 Quizzes** | Valid for 30 days. *Strict Expiration Rule:* The pass expires after 30 days; any unused generations from the 250-quiz quota are forfeited once the month elapses. |

### Illustrative Monthly Revenue Calculation:
In a month with 5,000 active nationwide free users during exam season:
* **300 Daily Passes sold** (300 × ₱20) = ₱6,000
* **180 Weekly Passes sold** (180 × ₱100) = ₱18,000
* **120 Monthly Passes sold** (120 × ₱250) = ₱30,000

$$\text{Estimated Monthly Pass Revenue} = \text{₱6,000} + \text{₱18,000} + \text{₱30,000} = \mathbf{\text{₱54,000 / month}}$$

---

## 12. Pricing Strategy

| Product / Pass | Price | Strategic Objective & Scope |
| :--- | :--- | :--- |
| Core App & Manual Studio | Free (₱0) | Zero-barrier user acquisition. Manual creation and review are completely free. |
| 1-Day AI Pass | ₱20 | Low-cost microtransaction for students needing quick AI quiz generation right before an exam. Strict 24-hr expiry (up to 20 quizzes). |
| 7-Day AI Pass | ₱100 | Tailored for exam weeks (midterms, prelims, finals) with a 50-quiz AI ceiling. Strict 7-day expiry. |
| 1-Month AI Pass | ₱250 | Consistent review solution for rigorous semester study or licensure exam prep with a 250-quiz ceiling. Strict 30-day expiry. |
| Institutional License | Custom (₱5,000+/batch) | Institutional bulk reviewer packages for board exam review academies and school departments. |

Payment methods will integrate familiar local channels: GCash, Maya, ShopeePay, and mobile credit via local payment gateways (e.g., PayMongo / Xendit).

---

## 13. Operations Plan

### Daily Operations:
* **Platform Health & Uptime:** Monitor Firebase servers, Firestore database read/write quotas, and web hosting latency.
* **AI Pipeline Optimization:** Oversee Google Gemini API latency, manage prompt tokens, and handle document parsing exceptions.
* **Customer Support:** Process and resolve user tickets submitted through the Admin Dashboard within 24 hours.
* **Content & Security Monitoring:** Ensure security rules protect user-created quizzes and private documents.

### End-to-End Operational Workflow:
$$\text{Student Registers} \longrightarrow \text{Uploads Document (PDF/DOCX) or Topic} \longrightarrow \text{Gemini API Processes \& Formulates Questions} \longrightarrow \text{Student Edits \& Saves to Firestore \& Hive (Offline)} \longrightarrow \text{Student Conducts Flashcard/Quiz Session} \longrightarrow \text{Performance Analytics Updated}$$

---

## 14. Technology Plan

| Technology Tool | Category | Exact Purpose in Studieazy |
| :--- | :--- | :--- |
| **Flutter (Dart)** | Cross-Platform UI Framework | Single codebase delivering high-performance responsive experiences for Android and Web. |
| **Firebase Authentication** | Security / Identity | Manages user registrations, email/password logins, and Google Sign-In securely. |
| **Cloud Firestore** | Cloud NoSQL Database | Real-time persistence for quizzes, questions, user profiles, stats, and tickets. |
| **Google Gemini AI SDK** | Generative AI / NLP | Extracts structured question/answer pairs from uploaded study modules and topics. |
| **Hive (hive_flutter)** | Local Fast Key-Value Cache | Enables full offline study sessions, cached decks, and quick local app launch. |
| **Riverpod** | State Management | Provides testable, reactive architecture connecting UI with services. |
| **Hostinger / Firebase Hosting** | Web Hosting & Domain | Custom domain management, DNS routing, and fast web content delivery. |
| **GitHub** | Version Control | Source code management, branching, and team collaboration. |

---

## 15. Organizational Structure

| Role | Primary Responsibilities |
| :--- | :--- |
| **Kurt Daryl R. De Mesa**<br>*Project Lead & Full-Stack Developer* | Overall system architecture, Flutter UI/UX development, Firebase cloud integration, Gemini AI implementation, and business decision-making. |
| **Quality Assurance & Testing Lead** | Conducting multi-device testing (Android, Web browsers), verifying document parsing accuracy, and identifying software bugs. |
| **Marketing & Community Officer** | Managing social media accounts (TikTok, Facebook), driving campus ambassador campaigns, and producing promotional video content. |
| **Customer Support Specialist** | Managing user support tickets in the Admin Dashboard, resolving payment verification queries, and gathering student feedback. |

*Note: During early-stage operations, core team members perform cross-functional responsibilities to maintain a lean operating structure.*

---

## 16. Financial Plan

### Estimated Startup Capital (Initial Setup)
The startup budget utilizes actual market pricing for genuine industry tools and services in the Philippines:

| Startup Expense Item | Real Tool / Service Provider | Estimated Cost (PHP) |
| :--- | :--- | :---: |
| Domain Registration (1 Year) | Hostinger (`studieazy.com` / `.ph` registration + privacy protection) | ₱1,000 |
| Cloud Hosting & Storage Buffer | Firebase Blaze Plan / Hostinger Web Tier (Initial deployment buffer) | ₱1,500 |
| Google Play Console Account | Google Play Developer License (One-time $25 USD registration fee) | ₱1,450 |
| AI Token Reserve Fund | Google Cloud / Gemini API Pre-funded Usage Credits | ₱2,500 |
| Graphic Design & Branding | Canva Pro Annual Subscription (Branding, promo assets, logo design) | ₱1,500 |
| Initial Marketing & Campus Launch | Targeted Meta / TikTok student ads & campus sticker/flyer giveaways | ₱3,000 |
| Internet & Communication Utility | PLDT / Converge High-speed Fiber connection allocation | ₱1,500 |
| Miscellaneous & Contingency | Buffer for payment gateway fees, transaction charges, and setup needs | ₱2,000 |
| **Total Estimated Startup Cost** | | **₱14,450** |

---

## 17. Estimated Monthly Expenses & Operational Income

### Projected Monthly Operating Expenses

| Operating Expense | Tool / Vendor Description | Monthly Cost (PHP) |
| :--- | :--- | :---: |
| Cloud Database & Server Operations | Firebase Blaze Plan (Firestore reads/writes, authentication, storage) | ₱1,500 |
| Generative AI Token Processing | Google Gemini API (Pay-as-you-go document parsing usage) | ₱2,800 |
| Web Hosting & Domain Maintenance | Hostinger Cloud / Web maintenance amortized | ₱300 |
| Targeted Student Marketing | Social media ads running during exam seasons (Midterms/Finals) | ₱3,500 |
| Internet & Developer Utilities | Team internet connection & developer tool maintenance | ₱1,500 |
| Administrative Contingency | Customer dispute reserves, payment gateway fees, miscellaneous | ₱1,200 |
| **Total Monthly Operating Expenses** | | **₱10,800** |

### Sample Monthly Financial Projection:
* **Projected Monthly Revenue:** ₱54,000  
* **Projected Monthly Expenses:** ₱10,800  
* **Illustrative Net Operating Income:** ₱54,000 − ₱10,800 = **₱43,200 / month**  

*(Disclaimer: This calculation represents an illustrative financial projection for academic technopreneurship evaluation and does not guarantee fixed profits).*

---

## 18. Risk Management

| Identified Risk | Severity | Mitigation Strategy |
| :--- | :--- | :--- |
| **Surging AI API Token Costs** | Medium | Enforce strict tier caps (20/day, 50/week, 250/month), truncate redundant whitespace in uploaded documents, and cache generated decks. |
| **Intermittent Internet in Provinces** | High | Implement robust local offline storage using **Hive**, ensuring flashcard drills and quizzes run without data connection. |
| **Post-Exam User Churn** | Medium | Introduce continuous review categories (general knowledge, civil service, vocabulary, trivia) to maintain engagement between semesters. |
| **System Downtime or Data Loss** | High | Utilize automated Firestore backup procedures and distributed multi-region cloud database hosting. |
| **Competition from Foreign Apps** | Low | Maintain micro-pricing tailored to local allowances (₱20/day via GCash) that foreign competitors cannot match. |

---

## 19. Future Expansion

* **Google Play Store & Apple App Store Release:** Publish dedicated native mobile apps with push notification reminders and daily study streaks.
* **Multiplayer Study Battles:** Real-time head-to-head quiz showdowns between classmates.
* **PRC Board Exam Community Marketplace:** Allow certified topnotchers to publish and monetize verified reviewer decks.
* **Local E-Wallet Direct API Integration:** Seamless one-tap GCash and Maya payments without manual receipt uploads.
* **Regional Expansion:** Localize the platform for universities across Southeast Asia (Indonesia, Vietnam, Thailand).

---

## 20. Implementation Timeline

| Phase | Key Activity | Timeline |
| :--- | :--- | :--- |
| **Phase 1** | Problem Discovery & Student Requirement Analysis | Weeks 1–2 |
| **Phase 2** | System Architecture & UI/UX Prototyping in Flutter | Weeks 3–4 |
| **Phase 3** | Firebase Authentication, Firestore, & Riverpod State Setup | Weeks 5–7 |
| **Phase 4** | Google Gemini AI Document Parsing Engine & Hive Offline Sync | Weeks 8–10 |
| **Phase 5** | Admin Dashboard, Support Ticket System & Internal Testing | Weeks 11–12 |
| **Phase 6** | University Beta Testing & Campus Ambassador Rollout | Weeks 13–14 |
| **Phase 7** | Nationwide Public Launch & Monetization Activation | Week 15 onwards |

---

## 21. Key Performance Indicators (KPIs)

| Key Performance Indicator | 3-Month Target | 6-Month Target | 12-Month Target |
| :--- | :---: | :---: | :---: |
| **Total Registered Students** | 1,500 | 6,000 | 25,000 |
| **Monthly Active Users (MAU)** | 800 | 3,500 | 15,000 |
| **Total Quizzes Created** | 5,000 | 25,000 | 120,000 |
| **AI Document Generations** | 2,500 | 12,000 | 60,000 |
| **Paid Access Passes Sold (Daily/Weekly/Monthly)** | 200 | 1,200 | 6,000 |
| **30-Day Student Retention Rate** | 40% | 50% | 60% |

---

## 22. Conclusion

**Studieazy** exemplifies how cutting-edge generative technology can be channeled into an accessible, practical, and viable technopreneurship venture. By dismantling the friction of manual reviewer creation through Google Gemini AI, and by providing engaging study modes with offline support, Studieazy directly empowers students to overcome study anxiety and achieve academic excellence.

With a revenue model intentionally engineered for the realities of student budgeting (₱20/day, ₱100/week, ₱250/month) and clear expansion avenues into review center licensing, Studieazy combines sound commercial fundamentals, technological feasibility, and meaningful educational impact nationwide.

---

## 23. Technopreneurship Academic Alignment

This business plan adheres strictly to technopreneurship requirements by addressing every core technological and business dimension:

* **What is your business?** Studieazy — an AI-powered study platform and interactive quiz/flashcard generator.
* **What problem does it solve?** Ineffective cramming, passive studying, hours wasted making manual reviewers, and high costs of foreign alternatives.
* **Who are your customers?** High school and college students, board exam reviewees, and educational review academies nationwide.
* **What product or service will you offer?** Cross-platform mobile/web application, automated document parsing, offline study decks, and admin dashboard.
* **Who are your competitors?** Quizlet, Anki, Studocu, and physical review books.
* **How will you earn money?** Daily (₱20, max 20 quizzes, 1-day expiry), Weekly (₱100, max 50 quizzes, 7-day expiry), and Monthly (₱250, max 250 quizzes, 30-day expiry) AI passes tailored to student allowances, plus B2B review center licenses.
* **How much money do you need to start?** Approximately ₱14,450 utilizing genuine tools (Hostinger, Google Play, Firebase, Canva, Meta/TikTok ads).
* **How will you market your business?** Viral "StudyTok" content, university student council tie-ups, campus ambassadors, and referral loops.
* **What technology will you use?** Flutter (Dart), Firebase Auth & Firestore, Google Gemini Generative AI, Hive offline cache, and Hostinger.
* **What risks might your business face?** AI token surges, offline connectivity limits, and vacation churn—mitigated by tier limits, local caching, and non-academic decks.
* **How will your business grow?** Transition from university hubs to nationwide licensure review centers and regional Southeast Asian expansion.
