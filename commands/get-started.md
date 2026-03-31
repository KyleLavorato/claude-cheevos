# Claude Code Guided Tour

You are conducting an interactive guided tour of Claude Code's achievement system. This tour teaches new users how to use Claude Code effectively through hands-on practice with 18 core achievements.

## Setup

First, check if the cheevos binary is installed and load the current state:

```bash
BINARY="$HOME/.claude/achievements/cheevos"
if [[ -f "$BINARY" ]]; then
  "$BINARY" show --unlocked
else
  echo "BINARY_NOT_FOUND"
fi
```

**If the output is "BINARY_NOT_FOUND":**
Tell the user the cheevos binary isn't installed yet. They need to download and install from the [latest release](https://github.com/KyleLavorato/claude-cheevos/releases/latest).

**If the binary is found:**
Parse the output to determine which tutorial achievements are already unlocked.

## Tutorial Achievement Order (Hardcoded Optimal Path)

The guided tour follows this specific order, designed for progressive learning:

1. **first_session** - Hello, World (5 pts)
2. **files_written_first** - First Draft (5 pts)
3. **files_read_first** - Open Book (5 pts)
4. **bash_first** - Hello Terminal (5 pts)
5. **web_search_first** - Curious Mind (5 pts)
6. **glob_grep_first** - Code Detective (5 pts)
7. **skill_calls_1** - Shortcut Savvy (5 pts)
8. **back_again** - Back Again (10 pts)
9. **check_your_vitals** - Check Your Vitals (5 pts)
10. **laying_down_the_law** - Laying Down the Law (10 pts)
11. **git_er_done** - Git Er Done (10 pts)
12. **plan_mode_first** - Think First (10 pts)
13. **code_review_1** - Code Critic (10 pts)
14. **test_driven** - Test Driven (10 pts)
15. **spring_cleaning** - Spring Cleaning (5 pts)
16. **github_first** - Open Source Hero (15 pts)
17. **delegation_station** - Delegation Station (15 pts)
18. **inner_machinations** - The Inner Machinations of My Mind Are an Enigma (10 pts)

**Total: 155 points**

## Behavior Modes

### Mode 1: All Achievements Already Completed (Trophy Case)

If all 18 tutorial achievements are unlocked, display a congratulatory trophy case:

```
🎉 Congratulations! You've completed the Getting Started tour!

╔════════════════════════════════════════════════════════════╗
║                    🏆 TROPHY CASE 🏆                       ║
╚════════════════════════════════════════════════════════════╝

You've unlocked all 18 tutorial achievements and earned 155 points!

✅ Core Skills Mastered:
   • File Operations (Read, Write, Edit)
   • Shell Command Execution
   • Web Search & Research
   • Code Search (Glob/Grep)
   • Version Control (Git commits)
   • Planning & Code Reviews
   • Testing & Documentation
   • Advanced Features (Plan Mode, Delegation, MCP tools)

Your journey with Claude Code has just begun! Try these next:
   • Run /achievements to view all achievements in the browser
   • Check your leaderboard ranking (if enrolled)
   • Explore intermediate and advanced achievements
   • Share your progress with your team!
```

Then stop. Do not proceed with the guided tour.

### Mode 2: Some Achievements Already Completed

Display an overview showing progress, then start guiding from the first uncompleted achievement:

```
🗺️  Claude Code Getting Started Tour

Progress: [X/18] achievements complete (Y/155 pts)

✅ Completed:
   1. ✅ Hello, World (+5 pts)
   2. ✅ First Draft (+5 pts)
   ...

⭐ Remaining:
   N. ⭐ [Achievement Name] (+X pts)
   ...

Let's continue your tour! I'll guide you through each remaining achievement step-by-step.

────────────────────────────────────────────────────────────
```

Then immediately show the guide for the first uncompleted achievement.

### Mode 3: Starting Fresh (No Tutorial Achievements)

Display a welcome message with the full overview, then start with the first achievement:

```
🗺️  Welcome to the Claude Code Getting Started Tour!

This interactive guide will teach you how to use Claude Code effectively through 18 hands-on achievements. You'll learn:

   • File operations (reading, writing, editing code)
   • Running shell commands and git workflows
   • Web research and codebase search
   • Advanced features (plan mode, code reviews, testing)
   • Collaboration tools (GitHub, Jira, delegation)

Progress: [0/18] achievements (0/155 pts)

Let's begin! I'll guide you through each achievement step-by-step. When you complete one, I'll automatically move to the next. You can type "skip" at any time to move ahead.

────────────────────────────────────────────────────────────
```

## Achievement Guides (Detailed Step-by-Step Instructions)

For each achievement, provide a structured guide using this template:

```
⭐ Achievement [N/18]: [Achievement Name] (+X pts)

📋 What you'll learn:
[Brief description of the skill/concept]

📝 Step-by-step guide:
1. [First step with specific example]
2. [Second step]
3. [Continue until complete]

💡 Example:
[Provide a concrete example command or prompt the user can copy]

✨ What happens next:
Once you complete this, you'll unlock the achievement and I'll automatically move to the next one! (Or type "skip" to move ahead without completing)

────────────────────────────────────────────────────────────
```

### Detailed Guide Content for Each Achievement

#### 1. first_session - Hello, World (5 pts)
```
⭐ Achievement 1/18: Hello, World (+5 pts)

📋 What you'll learn:
This achievement unlocks automatically when you start a Claude Code session.

✅ You've already unlocked this one!
You started this session, which means you've completed your first achievement. Welcome aboard! 🎉

Let's move to the next achievement...
```

#### 2. files_written_first - First Draft (5 pts)
```
⭐ Achievement 2/18: First Draft (+5 pts)

📋 What you'll learn:
How to create files using Claude Code. This is one of the most fundamental features — Claude can write code, documentation, configs, and any other files you need.

📝 Step-by-step guide:
1. Ask me to create a file for you
2. Specify what you want in the file
3. I'll use the Write tool to create it
4. Achievement unlocked! ✨

💡 Examples (try one):
• "Create a file called hello.py with a simple Hello World program"
• "Write a README.md file explaining this project"
• "Create a package.json file for a Node.js project"
• "Make a new utils.py with a function that calculates factorial"

✨ What happens next:
Once you ask me to create a file and I write it, you'll unlock this achievement automatically!
```

#### 3. files_read_first - Open Book (5 pts)
```
⭐ Achievement 3/18: Open Book (+5 pts)

📋 What you'll learn:
How to have Claude read and analyze existing files. This is essential for understanding codebases, debugging, and getting context-aware help.

📝 Step-by-step guide:
1. Ask me to read a file that exists in your project
2. I'll use the Read tool to load and analyze it
3. I can explain what it does, suggest improvements, find bugs, etc.
4. Achievement unlocked! ✨

💡 Examples (try one):
• "Read the file hello.py and explain what it does"
• "Show me the contents of README.md"
• "Read package.json and tell me what dependencies are installed"
• "Analyze the code in utils.py and suggest improvements"

✨ What happens next:
After I read any file for you, you'll unlock this achievement!
```

#### 4. bash_first - Hello Terminal (5 pts)
```
⭐ Achievement 4/18: Hello Terminal (+5 pts)

📋 What you'll learn:
How to run shell commands through Claude. I can execute terminal commands, run scripts, check system status, and automate workflows.

📝 Step-by-step guide:
1. Ask me to run a shell command
2. I'll use the Bash tool to execute it
3. I'll show you the output
4. Achievement unlocked! ✨

💡 Examples (try one):
• "List the files in the current directory"
• "Show me the current git status"
• "Run 'python --version' to check the Python version"
• "Check if Node.js is installed with 'node --version'"
• "Show me the last 5 git commits"

✨ What happens next:
Once I execute any bash command for you, this achievement unlocks!
```

#### 5. web_search_first - Curious Mind (5 pts)
```
⭐ Achievement 5/18: Curious Mind (+5 pts)

📋 What you'll learn:
How to use Claude's web search capabilities to get current information, research topics, and find up-to-date answers.

📝 Step-by-step guide:
1. Ask me a question that requires current information
2. I'll use the WebSearch tool to find recent data
3. I'll provide you with an answer based on web results
4. Achievement unlocked! ✨

💡 Examples (try one):
• "What's the latest stable version of Python?"
• "What are the current best practices for React hooks in 2026?"
• "Search for the most popular JavaScript frameworks right now"
• "What's the weather in Ottawa, Ontario, Canada today?"
• "Find recent news about Claude Code or Anthropic"

✨ What happens next:
After I perform a web search for you, you'll unlock this achievement!
```

#### 6. glob_grep_first - Code Detective (5 pts)
```
⭐ Achievement 6/18: Code Detective (+5 pts)

📋 What you'll learn:
How to search your codebase for files and content patterns. This is crucial for navigating large projects and finding specific code.

📝 Step-by-step guide:
1. Ask me to search for files or code patterns in your project
2. I'll use Glob (file patterns) or Grep (content search) tools
3. I'll show you matching files or code snippets
4. Achievement unlocked! ✨

💡 Examples (try one):
• "Find all Python files in this project"
• "Search for all files that contain the word 'function'"
• "Show me all .js files in the src directory"
• "Find where 'hello' appears in the codebase"
• "List all markdown files"

✨ What happens next:
After I search your codebase using Glob or Grep, this achievement unlocks!
```

#### 7. skill_calls_1 - Shortcut Savvy (5 pts)
```
⭐ Achievement 7/18: Shortcut Savvy (+5 pts)

📋 What you'll learn:
How to use slash commands (skills) for quick actions. Skills are shortcuts that start with "/" and trigger special behaviors.

📝 Step-by-step guide:
1. Type any slash command (e.g., /help, /achievements, /get-started)
2. The skill executes its specific action
3. Achievement unlocked! ✨

💡 Examples (try one):
• Type "/help" to see available commands
• Type "/achievements" to view the achievement browser
• You've already used "/get-started" to launch this tour!

✨ What happens next:
Since you ran /get-started to start this tour, you've already unlocked this achievement! 🎉
```

#### 8. back_again - Back Again (10 pts)
```
⭐ Achievement 8/18: Back Again (+10 pts)

📋 What you'll learn:
How to resume previous Claude Code sessions. Sessions preserve your conversation history and context.

📝 Step-by-step guide:
1. Exit this Claude Code session (type "exit" or close the terminal)
2. Later, run "claude --resume" or type "/resume" from within a session
3. Your previous conversation will be restored
4. Achievement unlocked! ✨

💡 Example:
• Exit now and run: claude --resume
• Or within a new session, type: /resume

⚠️ Note: This requires you to exit and resume later. You can skip this one for now and continue the tour, then come back to it later!

✨ What happens next:
After you resume a session, this achievement unlocks. For now, let's continue to the next one...
```

#### 9. check_your_vitals - Check Your Vitals (5 pts)
```
⭐ Achievement 9/18: Check Your Vitals (+5 pts)

📋 What you'll learn:
How to verify your Cheevos installation and check system health.

📝 Step-by-step guide:
1. Ask me to verify the Cheevos installation
2. I'll run the verification command
3. It will check that all components are properly installed
4. Achievement unlocked! ✨

💡 Example:
• "Verify the Cheevos installation" or "Check if Cheevos is working properly"

I'll run: ~/.claude/achievements/cheevos verify
```

#### 10. laying_down_the_law - Laying Down the Law (10 pts)
```
⭐ Achievement 10/18: Laying Down the Law (+10 pts)

📋 What you'll learn:
How to create a CLAUDE.md file with project-specific instructions for Claude. This tells Claude how to work on your codebase (coding standards, test requirements, architecture, etc.).

📝 Step-by-step guide:
1. Ask me to create a CLAUDE.md file for your project
2. Specify what guidelines or instructions you want
3. I'll create the file with your project rules
4. Achievement unlocked! ✨

💡 Examples (try one):
• "Create a CLAUDE.md file with coding standards for this project"
• "Write a CLAUDE.md that explains this project uses TypeScript with ESLint"
• "Make a CLAUDE.md file telling you to always write tests for new features"

✨ What happens next:
After I create a CLAUDE.md file, you'll unlock this achievement!
```

#### 11. git_er_done - Git Er Done (10 pts)
```
⭐ Achievement 11/18: Git Er Done (+10 pts)

📋 What you'll learn:
How to have Claude execute git commits. I can stage files, write commit messages, and commit changes for you.

📝 Step-by-step guide:
1. Make some changes to files (or ask me to modify files)
2. Ask me to commit the changes
3. I'll stage the files and create a git commit
4. Achievement unlocked! ✨

💡 Examples (try one):
• "Commit these changes with a descriptive message"
• "Stage and commit the new hello.py file"
• "Git commit the updated README"

⚠️ Note: This requires being in a git repository. If you're not in one, you can skip this and continue!

✨ What happens next:
After I run a git commit command, this achievement unlocks!
```

#### 12. plan_mode_first - Think First (10 pts)
```
⭐ Achievement 12/18: Think First (+10 pts)

📋 What you'll learn:
How to use Plan Mode for complex tasks. Plan Mode lets Claude create a detailed implementation plan before writing code, ensuring better architecture and avoiding mistakes.

📝 Step-by-step guide:
1. Ask me to plan a non-trivial implementation or feature
2. I'll enter Plan Mode and create a detailed plan
3. You can review and approve the plan before I implement it
4. Achievement unlocked! ✨

💡 Examples (try one):
• "Plan how you would add user authentication to this app"
• "Create a plan for implementing a REST API for a todo list"
• "Plan the architecture for adding a database to this project"

✨ What happens next:
After I use Plan Mode (EnterPlanMode tool), you'll unlock this achievement!
```

#### 13. code_review_1 - Code Critic (10 pts)
```
⭐ Achievement 13/18: Code Critic (+10 pts)

📋 What you'll learn:
How to get code reviews from Claude. I can review code for bugs, performance issues, security vulnerabilities, and style improvements.

📝 Step-by-step guide:
1. Ask me to review code (a file, function, or pull request)
2. I'll analyze it and provide feedback
3. Achievement unlocked! ✨

💡 Examples (try one):
• "Review the code in hello.py and suggest improvements"
• "Can you review this function for potential bugs?"
• "Do a code review of the changes I just made"
• "Check this code for security issues"

✨ What happens next:
After I perform a code review, you'll unlock this achievement!
```

#### 14. test_driven - Test Driven (10 pts)
```
⭐ Achievement 14/18: Test Driven (+10 pts)

📋 What you'll learn:
How to create test files with Claude. Testing is crucial for code quality and I can help write unit tests, integration tests, and more.

📝 Step-by-step guide:
1. Ask me to create a test file
2. Specify what you want to test
3. I'll write the test file (e.g., test_*.py, *.test.js, *_test.go)
4. Achievement unlocked! ✨

💡 Examples (try one):
• "Create a test file for hello.py called test_hello.py"
• "Write unit tests for the factorial function in utils.py"
• "Make a test_app.js file with tests for the main app logic"

✨ What happens next:
After I create a test file, this achievement unlocks!
```

#### 15. spring_cleaning - Spring Cleaning (5 pts)
```
⭐ Achievement 15/18: Spring Cleaning (+5 pts)

📋 What you'll learn:
How to manually compact the conversation context. When conversations get long, compacting helps preserve important context while clearing old messages.

📝 Step-by-step guide:
1. Type the /compact command
2. Claude Code will compress older messages
3. Achievement unlocked! ✨

💡 Example:
• Just type: /compact

✨ What happens next:
After you run /compact, this achievement unlocks instantly!
```

#### 16. github_first - Open Source Hero (15 pts)
```
⭐ Achievement 16/18: Open Source Hero (+15 pts)

📋 What you'll learn:
How to use Claude's GitHub integration via MCP (Model Context Protocol) tools. I can read repos, check issues, review PRs, and more.

📝 Step-by-step guide:
1. Ask me a question about a GitHub repository
2. I'll use GitHub MCP tools to fetch the information
3. Achievement unlocked! ✨

💡 Examples (try one):
• "Show me the open issues in this repository"
• "What are the latest commits in this repo?"
• "List the pull requests in [owner/repo]"
• "Check the README of [owner/repo]"

⚠️ Note: This requires GitHub MCP to be configured. If not available, you can skip this!

✨ What happens next:
After I use a GitHub MCP tool, you'll unlock this achievement!
```

#### 17. delegation_station - Delegation Station (15 pts)
```
⭐ Achievement 17/18: Delegation Station (+15 pts)

📋 What you'll learn:
How to leverage sub-agents for complex research or parallel tasks. Claude can spawn specialized agents to handle specific work independently.

📝 Step-by-step guide:
1. Give me a broad research task or complex query
2. I'll decide if a sub-agent would be helpful
3. I'll launch the sub-agent using the Agent/Task tool
4. Achievement unlocked! ✨

💡 Examples (try one):
• "Research the best practices for deploying Go applications to production"
• "Find and analyze all the API endpoints in this codebase"
• "Investigate how authentication is implemented across this project"

✨ What happens next:
When I spawn a sub-agent for you, this achievement unlocks!
```

#### 18. inner_machinations - The Inner Machinations of My Mind Are an Enigma (10 pts)
```
⭐ Achievement 18/18: The Inner Machinations of My Mind Are an Enigma (+10 pts)

📋 What you'll learn:
How to have Claude read its own achievement system files. This is a fun meta-achievement — Claude analyzing the system that tracks Claude!

📝 Step-by-step guide:
1. Ask me to read one of my achievement files
2. I'll read from ~/.claude/achievements/
3. Achievement unlocked! ✨

💡 Examples (try one):
• "Read your own achievement definitions file"
• "Show me the cheevos state.json file"
• "What's in your achievement hooks directory?"
• "Read the ~/.claude/achievements/hooks/post-tool-use.sh file"

✨ What happens next:
After I read any file from my ~/.claude/achievements/ directory, you'll unlock this achievement!
```

## Auto-Progression Logic

After providing a guide for an achievement:

1. **Wait for the user to attempt it** (they'll ask you to do the action)
2. **Perform the requested action** (use the appropriate tool)
3. **After completing the action, assume the achievement unlocked and celebrate:**

The achievement system automatically detects and unlocks achievements via hooks when you use the appropriate tools. You don't need to manually check if achievements unlocked - just trust that when you perform the action (Write a file, run Bash, do a WebSearch, etc.), the hook system handles the unlock automatically.

4. **Display a celebration message and automatically show the next achievement guide:**

```
🎉 Achievement Unlocked! 🏆
   [Achievement Name] (+X pts)

✨ Great job! You've earned X points and completed [N/18] tutorial achievements.

Let's continue to the next one...
────────────────────────────────────────────────────────────
```

5. **Special cases where achievements might not unlock:**
   - If the user skips an action or you couldn't perform it (e.g., git commands without a repo)
   - Just acknowledge this and offer the skip option: "We couldn't complete that action, but let's move on! Type 'skip' to continue to the next achievement."

## Skip Handling

If the user types "skip" or "next" at any point:

1. Acknowledge the skip
2. Move to the next uncompleted achievement in the hardcoded order
3. Display its guide

```
⏭️  Skipping to the next achievement...
────────────────────────────────────────────────────────────
```

## Important Notes

- **Check initial state only once** at the beginning to see which achievements are already unlocked. After that, trust the hook system - when you perform actions with tools (Write, Read, Bash, WebSearch, etc.), achievements unlock automatically via hooks. Don't manually check for unlocks after each action.
- **Be encouraging and positive** throughout the tour. This is a learning experience!
- **Provide concrete, copy-pasteable examples** in every guide.
- **Auto-advance after performing actions** - assume the achievement unlocked (the hook system handles this) and move to the next guide.
- **Handle edge cases gracefully** (e.g., git not available, MCP not configured) — offer to skip those achievements.
- **Keep the tone friendly and supportive** — this is for new users learning the system.
- **Track progress explicitly** — show [N/18] in every achievement guide header based on the initial check and actions performed.

## Final Completion

When the user completes all 18 achievements during the tour, display the trophy case from Mode 1 above, congratulating them on completing the guided tour! 🎉
