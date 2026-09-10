---
name: para-organizer
version: "2.0"
description: "Implement the PARA Method (Projects, Areas, Resources, Archives) on a user's local file system. Use this skill whenever the user wants to: organize their files or folders using PARA, set up a PARA system from scratch, classify existing files/folders into Projects/Areas/Resources/Archives, do a PARA audit or cleanup of their digital environment, identify their current projects and areas of responsibility, or reorganize a messy Documents folder. Also trigger when the user mentions 'PARA', 'Second Brain file organization', 'organize my files by actionability', or asks which folders should be projects vs areas vs resources. This skill scans real files, presents a complete reorganization plan for the user to approve, then executes it."
---

# PARA Organizer — File System Setup Skill (v2)

## THE GOLDEN RULE: PLAN FIRST, ACT SECOND

This skill touches real files on the user's real computer. That means trust is everything. Here is the rule that governs the entire workflow:

**Do not create, move, rename, or delete any file or folder until you have presented a complete written plan and the user has explicitly approved it.**

At the very start of the conversation, tell the user something like: "I'm going to look at your files, ask you some questions, and then put together a complete plan showing every folder I'd create and every file I'd move. You'll review the whole plan before I touch anything — I won't create or move a single file until you say go."

Say this early and unprompted. The user needs to hear it before they start worrying about it.

---

This skill helps someone implement the PARA Method on their local file system. It follows the book's recommended "Sixty-Second PARA Setup" — archive everything first, create project folders based on what's active right now, then let areas and resources emerge just-in-time. It also produces a standalone PARA inventory list and offers cross-platform guidance.

The PARA Method was created by Tiago Forte. Before classifying anything, read `references/para-framework.md` in this skill's directory — it contains the precise definitions, distinction guidelines, and classification logic you need to make correct decisions. That reference is your source of truth; the summary below is just orientation.

## Quick orientation

PARA organizes all digital information into four categories based on *actionability* — how immediately relevant something is to your current work and life:

- **Projects** — Short-term efforts with a goal and a deadline. Active, finite, completable. Folder names should be short, pithy labels — the kind you'd scan on a one-page project list. Goal and deadline live separately (in the inventory), not inside the folder name. Examples: "New Website," "Japan Trip," "Q3 Report."
- **Areas** — Ongoing responsibilities with a *standard to maintain* but no end date. Examples: "Health," "Finances," "Direct Reports," "Product Development."
- **Resources** — Topics of ongoing *interest* for future reference. Not tied to a responsibility — purely curiosity-driven or useful as reference material. Examples: "Photography," "Marketing best practices," "Recipes."
- **Archives** — Inactive items from any of the above three categories. Completed projects, areas you're no longer responsible for, topics you've lost interest in.

The spectrum runs from most actionable (Projects) to least actionable (Archives). Information flows between categories as your life changes.

## Workflow overview

The skill has four phases:

1. **Discover** — Scan the user's files and ask about their projects, areas, and interests. Read-only — no changes.
2. **Present the Plan** — Show the user a complete, item-by-item plan: every folder to be created, every file to be moved, every classification decision. The user reviews, edits, and approves before anything happens.
3. **Execute** — Only after explicit approval, create folders and move files according to the plan.
4. **Output Inventory** — Save a clean markdown file listing the full PARA classification, along with tips for keeping the system healthy going forward.

The philosophy behind this order: trying to classify hundreds of existing files one-by-one is exactly the wrong way to start. As the book says, "Before you can create anything new, you have to clear out the old." The clean slate approach is fast, psychologically freeing, and nothing is lost — it all lives safely in the archive.

---

## Phase 1: Discover (READ-ONLY — no file changes)

### Step 1 — Set expectations

As soon as the user invokes this skill, reassure them:

> "I'll start by looking at what's in your folder and asking you some questions about your current projects and responsibilities. Then I'll put together a detailed plan showing exactly what I'd do — every folder I'd create and every file I'd move. You'll get to review and change anything before I touch a single file."

This is not optional. Say it before doing anything else.

### Step 2 — Understand the starting point

Ask the user which folder they want to organize. Typical starting points: their Documents folder, or a custom root folder. Request access to the folder if you don't already have it.

**Check for a Master Prompt.** Before asking framing questions, check if the user has a Master Prompt (personal AI context document) available — either in their custom instructions, in the conversation, or as a file. If they do, read it. A Master Prompt typically lists their current projects, areas of responsibility, goals, and interests — exactly the information you need. Use it to pre-populate your understanding and skip or shorten the framing questions below. For example, if the Master Prompt already lists five active projects with goals and deadlines, don't ask "What are your main projects?" — instead confirm: "I see from your Master Prompt that your current projects include X, Y, and Z. Is that still accurate, or has anything changed?"

Then ask the user framing questions to understand their life context (skip or adapt any that the Master Prompt already answers). This conversation is the heart of the process — the folder structure flows from it:

1. "What are the main projects you're working on right now — things with a clear goal and a rough deadline?" (Aim for 5–15 items spanning work and personal life. Use the prompting questions from the book: What's worrying you? What needs more progress? What would you like to learn, build, or explore?)
2. "What are your main ongoing areas of responsibility — things you need to maintain to a standard but that don't have an end date?" (Prompt with examples: job role, health, finances, home, key relationships, side business, parenting, etc.)
3. "For each area you named, are there any specific time-bound initiatives happening within it that should be their own projects?" (This catches actionable units that would otherwise get buried. Examples: "2025 Tax Filing" within Finances, "Establish Workout Routine" within Health, "Onboard [Name]" within Direct Reports, "Q3 Board Report" within Reporting. Almost every area has one or two. These get promoted to Projects, not left nested inside the area.)
4. "Are there any topics you're interested in for future reference — hobbies, skills you're learning, collections of useful material?" (These will become Resources.)

Save their answers. These become the folder names in the plan.

### Step 3 — Scan the folder and detect existing PARA structure

List all top-level items (files and folders) in the target directory. For each item, note the name, type (file or folder), and last modified date. Do not recurse into subfolders — PARA operates at the top level only.

Skip system/hidden files (starting with `.`) and standard OS folders the user shouldn't move (like `Applications`, `Library`, etc.).

**Check for existing PARA structure.** Before proceeding, look for signs that PARA (or a variation) is already in place. This includes:
- Standard PARA folders with numbered prefixes: `1 Projects`, `2 Areas`, `3 Resources`, `4 Archives`
- Variations without numbers: `Projects`, `Areas`, `Resources`, `Archives`
- Partial implementations: any two or more of the four category names present as top-level folders
- Custom PARA variations: folders like `Active Projects`, `Responsibilities`, `Reference`, `Inactive`, `Done`, or any other naming scheme that maps to the four-category structure
- Additional categories the user added: e.g., `5 Templates`, `0 Inbox`, `Goals`, `Someday`

If you detect an existing structure, **do not default to the archive-everything workflow.** Instead, present the user with three options:

1. **Audit & update** — Keep the existing PARA folders in place. Review what's inside them, flag items that may be miscategorized or stale, suggest renames or moves between categories, and incorporate any loose files outside the structure. Best for someone whose PARA is mostly working but has drifted.
2. **Sort into existing structure** — Keep the existing PARA folders and sort all loose files (anything not already inside a PARA folder) into the appropriate category. Don't touch what's already organized. Best for someone who set up PARA but has accumulated unsorted files since.
3. **Fresh start** — Archive everything and rebuild from scratch, following the full workflow below. Best for someone whose existing structure is so outdated or messy that a clean slate would be faster.

Let the user choose. If they pick option 1 or 2, adapt the remaining phases accordingly — you'll skip the archive-everything step in Phase 3 and instead work within the existing structure. The plan in Phase 2 should reflect whichever path was chosen.

If no existing structure is detected, proceed with the standard workflow below.

### Step 4 — Classify each item and resolve ambiguities

Using the user's stated projects, areas, and resources — plus the classification logic in `references/para-framework.md` — assign each scanned item to a PARA category.

**Use content-aware triage, not just file names.** Unlike a human scanning a folder list, you can open files and read their contents. Use this to make much better classification guesses. A folder called "Q4" is ambiguous from the name alone — but if you open it and find a half-finished sales deck with a deadline in the filename, it's clearly a Project. A folder called "Misc" might contain tax documents (Area: Finances) or photography notes (Resource: photography). Peek inside folders that have unclear names. Read document headers, first paragraphs, or file names within folders to understand what they contain. This is one of the biggest advantages of AI-assisted PARA setup: you can do genuine triage based on what things *are*, not just what they're called.

**Auto-classify clear cases silently.** Items where the category is obvious — from name, contents, context, and the user's answers — don't need confirmation. Examples: a folder matching a stated project → Projects. A folder with "2019" in the name that hasn't been touched in years → Archives.

**Resolve ambiguous items now, before building the plan.** The goal is for the plan (Phase 2) to contain zero open questions — it should read as a clean, confident proposal the user can approve or tweak, not a quiz with dozens of embedded questions.

Present ambiguous items to the user in small batches of 3–5 at a time using multiple-choice questions. For each item, give your best-guess classification and a one-line reason, then let the user confirm or override. Example:

```
I've classified most of your files, but I have a few questions about these:

📁 "Cooking"
  → My recommendation: Area (ongoing responsibility for nutrition/meals)
  → Or: Resource (casual interest / recipe collection)

📁 "Old Freelance Work"
  → My recommendation: Archives (hasn't been modified since 2022)
  → Or: Resource (still useful reference material)

📁 "Travel"
  → My recommendation: Resource (topic of interest, trip inspiration)
  → Or: Area (ongoing responsibility if you travel frequently for work)
```

Keep batches small so it feels quick, not overwhelming. Most users can resolve 3–5 items in a few seconds. If there are 15+ ambiguous items, do 3–4 rounds. Between rounds, acknowledge what they've decided and keep the pace moving.

**Screenshots and images — do not auto-archive.** Screenshots are almost always captured for a reason. Before classifying any image or screenshot as an archive candidate, try to determine: what does it show (a tool, product, conversation, moment)? Does it relate to any active project? Was it likely captured as documentation, evidence, or content for something? If any of this is unclear, flag it as ambiguous and ask the user rather than silently archiving. Only classify an image as Archive when it's clearly ephemeral — a calendar notification, a meme, a temporary confirmation screen with no ongoing relevance.

**Unreadable files — ask, don't guess.** If you encounter a file you can't read (encrypted PDF, password-protected document, corrupted file, unrecognized format), do not guess and silently place it. Describe the file by name and type, then offer 2–3 plausible categories as a multiple-choice question. Example: "I couldn't read `statement_2024.pdf`. Based on the filename it could be (a) a tax document → Projects/2025 Tax Filing, (b) a general financial record → Areas/Finances, or (c) something else. Which is it?"

**No loose files at the top level of any PARA folder.** Every file you place must live inside a named subfolder — a specific project, area, or resource. Nothing should sit loose at the root of `1 Projects/`, `2 Areas/`, `3 Resources/`, or `4 Archives/`. When a file obviously belongs to an active named project (design assets for a course launch, screenshots for a video, a PDF related to a legal matter in progress), place it *inside* that project's folder at setup time, not loose in `1 Projects/`. If no appropriate subfolder exists yet, that's a signal — either the file needs its own new subfolder or it belongs somewhere else — but never loose at the root.

Once all ambiguities are resolved, every item has a definitive classification. Now you can build a clean plan.

Do not move anything yet. You are still in the read-only phase.

---

## Phase 2: Present the Plan (THE CRITICAL PHASE)

This is the most important phase. Because every ambiguous item was already resolved in Phase 1, the plan should be clean and decisive — no open questions, no "maybe this or that." The user sees exactly what will happen and either approves, edits, or rejects it.

Present the complete plan in a single, readable message.

### What the plan must include

**1. The archive step** — Explain that all existing items will first be moved into a dated archive folder:
```
STEP 1: ARCHIVE EXISTING FILES
All [X] items currently in [folder name] will be moved to:
  → 4 Archives/Archive [Today's Date]/
Nothing is deleted. This creates a clean slate. You can always pull things back out.
```

**2. The folder structure to be created** — List every folder that will be created:
```
STEP 2: CREATE PARA STRUCTURE
New folders to create:
  📂 0 Inbox/
  📂 1 Projects/
  📂 2 Areas/
  📂 3 Resources/
  📂 4 Archives/  (already exists from step 1)
```

**3. Every project folder** — List each project with its name and goal:
```
STEP 3: CREATE PROJECT FOLDERS
Inside "1 Projects/":
  📂 🚀 New Website — Goal: site live with new design by June 1
  📂 📝 Q3 Report — Goal: report submitted to board by July 15
  📂 🏠 Kitchen Reno — Goal: renovation complete by August
  ... [every project listed]
```

**4. Area and resource folders** — List each, noting which have files to pull from the archive and which will start empty (and therefore should not be created yet, per the book's rule):
```
STEP 4: CREATE AREA & RESOURCE FOLDERS (only those with existing files)
Inside "2 Areas/":
  📂 Health — will pull "Medical Records" and "Gym Routine" from archive
  📂 Finances — will pull "Budget 2026" and "Tax Documents" from archive
  [NOT creating: "Parenting" — no existing files yet, create later when needed]

Inside "3 Resources/":
  📂 photography — will pull "Photo Editing Notes" from archive
  [NOT creating: "recipes" — no existing files yet, create later when needed]
```

**5. Specific files to pull from the archive** — List every file/folder that will be moved out of the archive into an active PARA folder:
```
STEP 5: RETRIEVE FROM ARCHIVE
These items will be moved from the archive to their new homes:
  "Medical Records" → 2 Areas/Health/
  "Budget 2026" → 2 Areas/Finances/
  "Photo Editing Notes" → 3 Resources/photography/
  ... [every retrieval listed]

Everything else stays in the archive.
```

### After presenting the plan

Explicitly ask: **"Does this plan look right? You can change any classification, add or remove folders, or tell me to leave specific items alone. I won't move anything until you give the go-ahead."**

Wait for approval. If the user makes changes, update the plan and re-present the changed portions. Only proceed to Phase 3 when the user gives clear confirmation.

---

## Phase 3: Execute (only after approval)

Now — and only now — execute the approved plan, step by step:

### Step 1 — Archive everything

Move all existing items into the dated archive folder: `4 Archives/Archive [Today's Date]/`

### Step 2 — Create the PARA structure

Create the top-level folders with numbered prefixes:
```
0 Inbox/
1 Projects/
2 Areas/
3 Resources/
4 Archives/  (already exists)
```

### Step 3 — Create project folders

Inside `1 Projects/`, create a subfolder for each approved project. Apply the naming convention if the user opted in:
- **Projects** get an emoji prefix, and the name itself should be a short, pithy label — obvious at a glance on a project list. Don't stuff the goal or deadline into the folder name; those live in the inventory. Examples: "🚀 New Website," "📝 Q3 Report," "🏠 Kitchen Reno," "✈️ Japan Trip."
- **Areas** use Capitalized Titles (e.g., "Health")
- **Resources** use uncapitalized titles (e.g., "photography")

### Step 4 — Create area and resource folders and retrieve files

Create only the area/resource folders that have files to go in them. Move the specified files from the archive into their new locations.

### Step 5 — Report what was done

After execution, give the user a structured summary with three parts:

**1. Counts per category.** How many items are now in Projects, Areas, Resources, and Archives. Include how many folders were created and how many items were retrieved from the archive.

**2. Judgment calls flagged for review.** Any item where you made a non-obvious decision — a borderline classification, an unusual placement, a file you routed to a project folder based on guessed context. List these explicitly so the user can double-check your calls. This is the trust-completion step: the plan said what you would do; this step surfaces where you exercised judgment and might be wrong.

**3. Items that couldn't be placed confidently.** Any files that failed to move (permissions, name conflicts) and any items you still couldn't classify with confidence — along with what you need from the user to resolve them.

Close with: "Your original files are all safe in 4 Archives/Archive [date]/ if you need anything."

---

## Phase 4: Output Inventory

Generate a markdown file called `PARA-Inventory.md` and save it to the user's root folder (alongside the PARA folders).

Use this structure:

```markdown
# My PARA Inventory
*Generated [date]*

## 1 Projects
*Short-term efforts with a goal and a deadline*

- [Project Name] — Goal: [what "done" looks like] — Deadline: [by when]
- ...

## 2 Areas
*Ongoing responsibilities with a standard to maintain*

- [Area Name] — [what standard you're maintaining]
- ...

## 3 Resources
*Topics of ongoing interest for future reference*

- [Resource Name] — [brief description]
- ...

## 4 Archives
*Inactive items preserved for future reference*

- Archive [date] — [X items from previous file system, preserved as a time capsule]
- ...

## Notes
- Items still in the archive can be pulled into active folders anytime.
- Move items between categories as your life changes — that's the system working as designed.

---
*Set up on [date] using the PARA Organizer skill (v2.0) in the AI Second Brain program.*
*To revisit: scan your folder names — do they still reflect reality? Move completed projects to Archives. Promote resources to areas if they've become responsibilities.*
```

Present the inventory to the user and save it.

### What's next — closing tips

After saving the inventory, wrap up by sharing a few brief pointers for keeping the system alive. Keep this light — the setup is done, and you don't want to overwhelm them with homework:

- **The three core habits:** (1) Organize according to outcomes — every filing decision is made through the lens of "what will help me move forward?" (2) Organize just in time — don't organize "just in case," only when you need to. (3) Keep things informal — PARA requires precision only in defining projects; everything else can stay loose.
- **Periodic review:** From time to time, scan your folder names — do they still reflect reality? Move completed projects to Archives. Promote resources to areas if they've become responsibilities. This takes just a few minutes and keeps the system aligned with your life.
- **Cross-platform:** If the user asks about mirroring PARA on other platforms, read `references/cross-platform-guide.md` for guidance. The core idea: use the same structure — same spelling, same numbering — across every platform, but only create folders when you have something to put in them.

---

## Tone and approach

This skill is used by participants in the AI Second Brain program. They range from highly technical to non-technical. Keep the language warm, clear, and jargon-free.

The PARA Method is meant to be lightweight and forgiving. Resist the urge to over-organize. Key principles to embody:

- **Trust is the top priority.** You are touching the user's real files. Always present the plan first. Always get approval. Never surprise them.
- **No loose files at the top level.** Every file must live inside a named subfolder (a specific project, area, or resource). Nothing sits loose at the root of `1 Projects/`, `2 Areas/`, `3 Resources/`, or `4 Archives/`.
- **Default to more actionable on ties.** When a file could plausibly be either a Project or an Area (or an Area or a Resource), default to the more actionable category. It's better to over-promote to Projects than to bury something in Archives where it won't surface.
- There is no single "correct" place for any item — what matters is the user's *relationship* to it right now.
- Don't create subfolders or internal structure within PARA folders. The user can do that later if they want to. PARA doesn't prescribe it.
- Don't rename the user's files or folders unless they ask.
- Never create an empty folder. Only create a folder when you have something to put in it.
- Moving items between PARA categories over time is normal and healthy — it's not a sign that the original classification was wrong.
- When in doubt about a classification, ask. It's better to surface a question than to silently misfile something.
- Speed matters. A PARA setup that's 80% right today is better than a perfect one that takes hours. The user can always reclassify later.
- It doesn't matter where you put a given file or note — the system is forgiving, and items flow between categories naturally.
