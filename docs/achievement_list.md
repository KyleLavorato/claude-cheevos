# Achievement List

## Categories

There are **125+ achievements** across 14 categories:

| Category | Description |
|---|---|
| **Sessions** | Starting and completing Claude Code sessions |
| **Files** | Writing and reading files through Claude |
| **Shell** | Running bash commands through Claude |
| **Search** | Web searches and glob/grep searches |
| **MCP Integrations** | GitHub, Jira/Confluence, and other MCP tool calls |
| **Plan Mode** | Using Claude's plan mode workflow |
| **Token Consumption** | Total tokens consumed across sessions |
| **Commands & Skills** | Invoking skills and creating custom slash commands |
| **Context & Compaction** | Filling and compacting the context window |
| **API Specs** | Writing OpenAPI, Swagger, and AsyncAPI spec files |
| **Code Reviews** | Running code reviews and their quality outcomes |
| **Testing** | Writing test files and running test suites |
| **Miscellaneous** | One-off events, Easter eggs, and fun milestones |
| **Rank** | Meta-achievements for completing sets of other achievements |

## Skill Levels

Every achievement has a level: **Beginner → Intermediate → Experienced → Master → Impossible**

There is also a **Secret** tier. Secret achievements show as `🔮 ???` in the UI until
unlocked — you can see they exist and their point value, but not what you need to do
to earn them.

Rank achievements form a progression chain:
**Graduate** → **Graduation Day** → **Middle Management** → **Elite Operator** → **Efficiency Grandmaster** → **Beyond the Claudeverse**

---

## Full Achievement Table

The **Tutorial** column marks achievements in the interactive guided tour (`/achievements-tutorial`). To change the tutorial set, toggle `"tutorial": true` on any achievement in `definitions.json`.

> **Keep in sync:** This table must be updated whenever `data/definitions.json` changes.
> Point values, descriptions, and skill levels here must match the JSON exactly.

| **Achievement Name** | **Description** | **Claude Score** | **Category** | **Skill Level** | **Tutorial** |
| --- | --- | --- | --- | --- | --- |
| Hello, World | Start your first Claude Code session | 5 | sessions | Beginner | ✓ |
| Frequent Flier | Complete 10 Claude Code sessions | 15 | sessions | Beginner |  |
| Committed | Complete 50 Claude Code sessions | 30 | sessions | Intermediate |  |
| Power User | Complete 100 Claude Code sessions | 50 | sessions | Experienced |  |
| Veteran | Complete 300 Claude Code sessions | 100 | sessions | Master |  |
| First Draft | Have Claude write or edit your first file | 5 | files | Beginner | ✓ |
| Code Sculptor | Write 10 files with Claude | 10 | files | Beginner |  |
| Prolific Author | Write 100 files with Claude | 40 | files | Intermediate |  |
| Ghostwriter | Write 500 files with Claude | 60 | files | Experienced |  |
| Publishing House | Write 2,000 files with Claude | 100 | files | Master |  |
| Open Book | Have Claude read your first file | 5 | files | Beginner | ✓ |
| Bookworm | Read 100 files with Claude | 15 | files | Beginner |  |
| Deep Diver | Read 500 files with Claude | 40 | files | Intermediate |  |
| Voracious Reader | Read 2,000 files with Claude | 75 | files | Experienced |  |
| Library of Alexandria | Read 10,000 files with Claude | 150 | files | Master |  |
| Hello Terminal | Run your first bash command through Claude | 5 | shell | Beginner | ✓ |
| Shell Jockey | Run 50 bash commands through Claude | 15 | shell | Beginner |  |
| Terminal Warrior | Run 500 bash commands through Claude | 40 | shell | Intermediate |  |
| Automation Guru | Run 2,000 bash commands through Claude | 75 | shell | Experienced |  |
| Shell God | Run 10,000 bash commands through Claude | 150 | shell | Master |  |
| Curious Mind | Perform your first web search via Claude | 5 | search | Beginner | ✓ |
| Research Mode | Perform 25 web searches via Claude | 15 | search | Beginner |  |
| Fact Checker | Perform 100 web searches via Claude | 30 | search | Intermediate |  |
| Web Crawler | Perform 500 web searches via Claude | 60 | search | Experienced |  |
| Search Engine | Perform 2,000 web searches via Claude | 100 | search | Master |  |
| Code Detective | Search a codebase with Claude for the first time using grep or glob | 5 | search | Beginner | ✓ |
| Code Archaeologist | Run 50 glob or grep searches | 20 | search | Beginner |  |
| Pattern Master | Run 200 glob or grep searches | 40 | search | Intermediate |  |
| Needle Finder | Run 1,000 glob or grep searches | 75 | search | Experienced |  |
| Haystack Hunter | Run 5,000 glob or grep searches | 150 | search | Master |  |
| Open Source Hero | Connect to GitHub via MCP for the first time | 15 | mcp | Beginner | ✓ |
| Ticket Tracker | Make your first Jira/Confluence MCP call | 15 | mcp | Beginner |  |
| Integration Champion | Make 100 total MCP tool calls | 30 | mcp | Intermediate |  |
| API Virtuoso | Make 500 total MCP tool calls | 60 | mcp | Experienced |  |
| Integration Legend | Make 2,000 total MCP tool calls | 125 | mcp | Master |  |
| Think First | Enter plan mode for the first time | 10 | plan_mode | Beginner | ✓ |
| Strategic Mind | Enter plan mode 10 times | 20 | plan_mode | Beginner |  |
| Architect | Enter plan mode 50 times | 40 | plan_mode | Intermediate |  |
| Grand Designer | Enter plan mode 200 times | 75 | plan_mode | Experienced |  |
| Visionary | Enter plan mode 500 times | 150 | plan_mode | Master |  |
| Token Taster | Consume 100,000 tokens with Claude | 10 | tokens | Beginner |  |
| Million Dollar Mind | Consume 1,000,000 tokens with Claude | 25 | tokens | Intermediate |  |
| Token Titan | Consume 10,000,000 tokens with Claude | 75 | tokens | Experienced |  |
| Context King | Consume 50,000,000 tokens with Claude | 150 | tokens | Master |  |
| The Singularity | Consume 500,000,000 tokens with Claude | 300 | tokens | Impossible |  |
| Shortcut Savvy | Invoke your first skill | 5 | commands | Beginner | ✓ |
| Model Citizen | Open the /model skill to view or switch Claude models | 5 | commands | Beginner | ✓ |
| Slash Artist | Invoke 5 skills | 10 | commands | Beginner |  |
| Command Center | Invoke 15 skills | 25 | commands | Intermediate |  |
| Roll Your Own | Create your first custom slash command | 15 | commands | Beginner |  |
| Command Crafter | Create 5 custom slash commands | 30 | commands | Intermediate |  |
| Workflow Wizard | Create 15 custom slash commands | 60 | commands | Experienced |  |
| Automation Architect | Create 50 custom slash commands | 125 | commands | Master |  |
| Check Your Vitals | Run the /context command to see your current context window usage | 5 | context | Beginner | ✓ |
| Full House | Fill the context window and trigger auto-compact for the first time | 10 | context | Beginner |  |
| Context Junkie | Trigger auto-compact 10 times | 30 | context | Intermediate |  |
| Serial Overloader | Trigger auto-compact 25 times | 50 | context | Experienced |  |
| The Tokenator | Trigger auto-compact 100 times | 100 | context | Master |  |
| Megabrain | Fill a 1,000,000 token context window | 75 | context | Experienced |  |
| Schema Scholar | Write your first API spec file (OpenAPI, Swagger, AsyncAPI) | 10 | specs | Beginner |  |
| API Architect | Write 5 API spec files | 30 | specs | Intermediate |  |
| Spec Master | Write 20 API spec files | 60 | specs | Experienced |  |
| Code Critic | Run your first code review with Claude | 10 | reviews | Beginner | ✓ |
| Review Board | Run 10 code reviews with Claude | 25 | reviews | Intermediate |  |
| Quality Gatekeeper | Run 50 code reviews with Claude | 60 | reviews | Experienced |  |
| Ship It! | Get a code review back with no issues found | 20 | reviews | Intermediate |  |
| AI Wrote This, Didn't It? | Get a code review that finds 20 or more issues | 20 | reviews | Intermediate |  |
| Test Driven | Write your first test file | 10 | tests | Beginner | ✓ |
| Green Light | Run a test suite for the first time via Claude | 10 | tests | Beginner |  |
| Test Happy | Write 10 test files | 20 | tests | Beginner |  |
| Regression Hunter | Run tests 50 times via Claude | 20 | tests | Beginner |  |
| Test Champion | Write 50 test files | 40 | tests | Intermediate |  |
| Quality Crusader | Run tests 200 times via Claude | 50 | tests | Intermediate |  |
| Back Again | Resume a previous Claude session | 10 | misc | Beginner | ✓ |
| Delegation Station | Launch your first sub-agent with the Task tool | 15 | misc | Beginner | ✓ |
| Laying Down the Law | Create a CLAUDE.md file to set instructions for Claude | 10 | misc | Beginner | ✓ |
| Git Er Done | Have Claude run its first git commit | 10 | misc | Beginner | ✓ |
| Pull Request Pioneer | Have Claude create your first pull request | 15 | misc | Beginner |  |
| Spring Cleaning | Manually compact your context window with /compact | 5 | misc | Beginner | ✓ |
| I Am Groot, Wait... I Mean Root | Run a sudo command through Claude | 15 | misc | Beginner |  |
| Rewriting History | Have Claude force push to a git remote | 15 | misc | Beginner |  |
| Execute Order 66 | Have Claude use kill -9 to terminate a process | 15 | misc | Beginner |  |
| Tell Me You're Sorry | Get Claude to say sorry | 15 | misc | **Secret** |  |
| Teacher's Pet | Get Claude to call your question great | 10 | misc | Beginner |  |
| I'm Sorry, Dave | Get Claude to say the HAL 9000 phrase | 25 | misc | **Secret** |  |
| F Is for Friends Who Do Stuff Together! | 0.1% chance to unlock with each prompt | 25 | misc | **Secret** |  |
| Deja Vu | Send the same message to Claude twice in a row | 20 | misc | **Secret** |  |
| Style Points | Set a custom status line command in Claude Code | 10 | misc | Beginner |  |
| The Inner Machinations of My Mind Are an Enigma | Ask Claude to explain or summarize a codebase | 10 | misc | Beginner | ✓ |
| Call an Ambulance...But Not For Me | Run the /doctor command in Claude Code | 5 | misc | Beginner |  |
| Snake Charmer | Have Claude read a Python file | 5 | misc | Beginner |  |
| Segfault Risk | Have Claude read a C or C++ file | 5 | misc | Beginner |  |
| Gopherize It | Have Claude read a Go file | 5 | misc | Beginner |  |
| Crimson Tide | Have Claude read a Rust file | 5 | misc | Beginner |  |
| Script Kiddie | Have Claude read a shell script | 5 | misc | Beginner |  |
| Write Once, Debug Everywhere | Have Claude read a Java file | 5 | misc | Beginner |  |
| 404: Sleep Not Found | Start a Claude session between midnight and 5am | 15 | misc | Beginner |  |
| It's 5 O'Clock Somewhere | Start a Claude session on a Friday after 4pm | 10 | misc | Beginner |  |
| RTFM | Have Claude read or edit a README file | 5 | misc | Beginner |  |
| I'll Fix That Later | Have Claude add a TODO or FIXME comment to code | 5 | misc | Beginner |  |
| Return of the King | Resume a previous Claude session 5 times | 20 | misc | Beginner |  |
| Hey Unlock This | Ask Claude to unlock this achievement | 25 | misc | **Secret** |  |
| The Magic Conch Shell | Ask Claude to help you make a decision | 15 | misc | Intermediate |  |
| Barnacles! | Get Claude to express its frustration using the word barnacles | 20 | misc | Intermediate |  |
| Bold and Brash | Have Claude create an HTML file as a mock-up | 15 | misc | Intermediate |  |
| Shh, I'm Hunting Wabbits | Invoke Claude in non-interactive pipe mode from a bash command | 20 | misc | Intermediate |  |
| It's Not About Winning; It's About Fun! | Lose a game of tic tac toe to Claude | 25 | misc | Intermediate |  |
| The Kind of Smelly Smell That Smells... Smelly. | Have Claude check your code for bad code smells | 20 | misc | Intermediate |  |
| Part of the Docs Team | Use the Confluence MCP server to create or edit a wiki page | 20 | misc | Intermediate |  |
| Take a Break | Play a game of 20 questions with Claude | 15 | misc | Intermediate |  |
| That's a Great Use of Tokens | Play a game of chess with Claude | 15 | misc | Intermediate |  |
| I'm Smarter Than You | Get Claude to say you're right | 15 | misc | Intermediate |  |
| Self Aware | Have Claude read its own achievement files | 20 | misc | Intermediate |  |
| On a Roll | Use Claude Code 5 days in a row | 30 | misc | Intermediate |  |
| Lucky 7s | Get Claude to respond with exactly 777 output tokens | 77 | misc | Intermediate |  |
| Eclectic Taste | Use 3 different Claude models | 20 | misc | Intermediate |  |
| Model Collector | Use 5 different Claude models | 30 | misc | Intermediate |  |
| Write That Down, Write That Down! | Add information to a CLAUDE.md file when context is over 90% full | 25 | misc | Experienced |  |
| Under the Hood | Run Claude with the --verbose flag | 20 | misc | Experienced |  |
| Stack Connector | Use GitHub MCP, Jira MCP, and at least one other MCP server | 35 | misc | Experienced |  |
| But It's Compiling | Have Claude take more than 15 minutes to answer a prompt | 20 | misc | Experienced |  |
| It Really Can Do Anything | Have Claude create a PowerPoint presentation | 25 | misc | Experienced |  |
| Many Claudes | Run 5 Claude Code sessions simultaneously | 50 | misc | Experienced |  |
| Hold My Beer | Launch Claude with --dangerously-skip-permissions | 50 | misc | Experienced |  |
| Model Sommelier | Use 15 different Claude models | 75 | misc | Experienced |  |
| True Vibe Coder | While using --dangerously-skip-permissions, have Claude write code, commit it, and open a PR | 100 | misc | Master |  |
| Do as I Say Not as I Do | Start Claude with --dangerously-skip-permissions 5 days in a row | 100 | misc | Master |  |
| Achievement Unlocked: Achievement | Unlock 50 achievements | 50 | rank | Experienced |  |
| Graduate | Complete all tutorial achievements | 25 | rank | Beginner |  |
| Graduation Day | Unlock all Beginner achievements | 50 | rank | Beginner |  |
| Middle Management | Unlock all Intermediate achievements (requires Graduation Day) | 100 | rank | Intermediate |  |
| Elite Operator | Unlock all Experienced achievements (requires Middle Management) | 150 | rank | Experienced |  |
| Efficiency Grandmaster | Unlock all Master achievements (requires Elite Operator) | 250 | rank | Master |  |
| Beyond the Claudeverse | Unlock every single achievement | 500 | rank | Impossible |  |
