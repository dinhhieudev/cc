# Claude++ Workflow

[English](README.md) | Tiếng Việt

Một quy trình phát triển tính năng kết hợp **Claude Code** với một cuộc hội thoại **AI web** (ChatGPT / Gemini).

Claude Code phụ trách phần codebase (khám phá code, implementation, fix, git). AI web phụ trách planning và review.
Bạn review ở từng checkpoint và là người duy nhất chuyển nội dung qua lại giữa hai bên.

---

## Subagent — vì sao và chạy ở đâu cho mỗi bước

Các bước nặng về công việc codebase chạy trong một **subagent riêng** để main context không bị đầy:

| Bước | Chạy ở | Vì sao |
|---|---|---|
| 1 — Overview + tạo branch | Main context | Nhẹ — chỉ đọc prompt, ghi file, tạo git branch |
| 1 — Context | **context-agent** | Đọc nhiều file codebase → tách riêng |
| 3 — Execute | **execute-agent** | Implement nhiều thay đổi → tách riêng |
| 6 — Fix | **fix-agent** | Đọc file + áp fix → tách riêng |
| 7 — Save | Main context | Nhẹ — chỉ copy file, commit, và reset |

Bạn không cần làm gì thêm — Claude tự động route đến đúng subagent theo bảng trong `CLAUDE.md`.

Subagent **không thấy được** cuộc hội thoại chính. Bất cứ thứ gì bạn paste
(plan, fix list) đều được main context ghi ra file trước, sau đó mới dispatch subagent.

---

## Cài đặt vào một project

Đây là repo template — copy nó vào project đích trước khi dùng.
Có hai cách:

- **Option A — tự động, không tracked** (khuyến nghị khi team của project
  đích chưa thống nhất dùng workflow này, hoặc bạn đơn giản là không muốn
  các file của workflow xuất hiện trong `git status`/history).
- **Option B — thủ công, tracked** (các file của workflow, kể cả
  `.task/`, được commit vào repo đích như mọi file project khác — xem
  phần Directory Structure ở cuối README này).

### Option A — tự động, không tracked

Từ repo template này:

```bash
bash bin/install-untracked.sh /path/to/target-project
```

Truyền `--lang en|vi` để set `Language:` trong `.task/PROJECT.md` được cài
đặt (mặc định `en`); bị bỏ qua kèm ghi chú nếu target đã có `.task/`:
```bash
bash bin/install-untracked.sh --lang vi /path/to/target-project
```

Yêu cầu target đã là một git repository. Script sẽ:
- copy `.claude/agents/`, `.claude/instructions/`, `.claude/skills/{overview,save}/`,
  `.task/` (bỏ qua nếu target đã có sẵn — không bao giờ ghi đè task history hiện có),
  và `bin/{copy,diff}-for-web.sh` vào target
- merge bảng Agent Routing + hard rules từ `CLAUDE.md` của repo này
  vào `<target>/CLAUDE.local.md` thay vì đụng vào `CLAUDE.md` của target
- append một block đánh dấu marker vào `<target>/.gitignore` bao phủ mọi
  file vừa copy, để không có file nào bị stage

Script sẽ abort trước khi copy bất cứ thứ gì nếu `.claude/agents/{context,execute,fix}-agent.md`
hoặc `.claude/skills/{overview,save}/` đã tồn tại trong target với nội dung
khác. (xem Option B, phần c bên dưới, để biết cách xử lý thủ công). An toàn
khi chạy lại — một lần cài giống hệt cái đã có là no-op, không phải lỗi.

Sau khi hoàn tất, chuyển thẳng sang điền `.task/PROJECT.md`
(xem "Thiết lập ban đầu" bên dưới) — các phần a-e bên dưới không áp dụng cho path này.

### Option B — thủ công, tracked

#### a) Cần copy những gì

Từ repo template này vào root của project đích:

```
.claude/agents/
.claude/instructions/
.claude/skills/overview/
.claude/skills/save/
.task/
bin/
CLAUDE.md
```

Ví dụ:
```
cp -R .claude/agents .claude/instructions <target>/.claude/
cp -R .claude/skills/overview .claude/skills/save <target>/.claude/skills/
cp -R .task bin CLAUDE.md <target>/
```

`.task/done/` cũng phải được copy (nó đi kèm `README.md` riêng). Các file
`.task/*.md` khác đến dưới dạng template rỗng — đó là điều bình thường; chỉ
`.task/PROJECT.md` cần được điền tay.

#### b) Merge khi project đích đã có CLAUDE.md

Đừng ghi đè. Merge nội dung CLAUDE.md của template vào CLAUDE.md hiện có
của project, giữ nguyên toàn bộ:
- bảng `## Agent Routing` (mọi dòng)
- đoạn `N for ## Fix Notes — Round N` ngay dưới bảng
- danh sách `## Hard rules for main context` (cả 6 rule)

Lưu ý: CLAUDE.md của template này **không** dùng kiểu import
`@.task/PROJECT.md` — PROJECT.md được từng file `.claude/instructions/*.md`
đọc trực tiếp, nên nó chỉ load đúng một lần cho mỗi agent. Đừng thêm kiểu
import đó khi merge.

#### c) Merge khi project đích đã có `.claude/agents/` hoặc `.claude/skills/`

Tên không được trùng: `context-agent`, `execute-agent`, `fix-agent`,
`overview`, `save`. Nếu tên nào đã tồn tại trong project đích, đổi tên một
bên và cập nhật mọi chỗ tham chiếu (bảng `Agent Routing` trong CLAUDE.md, và
pointer tới `.claude/instructions/*.md` trong file agent tương ứng).

#### d) Commit `.task/` vào project đích

`.task/` nên được commit vào repo của project đích — xem phần Directory
Structure ở cuối README này để biết chi tiết.

#### e) Verify việc cài đặt

Từ root của project đích:
- `bash bin/copy-for-web.sh --help` phải in usage.
- `bash bin/copy-for-web.sh` (khi chưa có task nào) phải fail sạch sẽ, báo
  rằng `.task/overview.md` vẫn còn là placeholder — điều này chứng minh
  script đang trỏ đúng vào `.task/` của project đích.

---

## Thiết lập ban đầu (chỉ một lần)

Điền vào `.task/PROJECT.md` — context cấp project mà không agent hay skill nào ghi đè:

- `Tech Stack`, `Architecture Overview`, `Key Conventions`, `Source Layout`,
  `Important Files`, `Known Constraints` — như bình thường.
- `## Verify Command` — một lệnh shell chứng minh build/typecheck sạch
  (ví dụ `npm run typecheck`, `swift build`). execute-agent và fix-agent
  **bắt buộc** phải chạy lệnh này trước khi báo done.
- `## Git` — `Base branch` (mặc định `main`) và `Task branch prefix`
  (mặc định `task/`).
- `## Language` — `Language: en` (mặc định) hoặc `vi`. Điều khiển ngôn ngữ
  văn xuôi mà agent dùng để viết trong các file `.task/*.md` và báo cáo
  cuối cùng. Các heading mà tooling grep (`## Fix Notes — Round N`, v.v.),
  đường dẫn file, tên branch, commit message, và code luôn giữ English bất kể giá trị này.

`.task/context.md` được **tự sinh cho mỗi task** (do context-agent ghi mỗi
lần) — **không bao giờ tự sửa tay file này**, mọi thay đổi sẽ bị ghi đè ở
task tiếp theo.

---

## Bước 1 — Claude Code: phân tích yêu cầu + tạo branch

**Prompt:**
```
skill overview + context: [mô tả yêu cầu, có thể kèm tên file hoặc code paste vào]
```

**Ví dụ:**
```
skill overview + context: sửa tính năng login, cần lưu token và
refresh token vào keychain sau khi API login thành công @login.dart
```

Claude chạy overview trong main context → tạo task branch (`{prefix}{id}-{slug}`
từ base branch trong `.task/PROJECT.md`) → tự gọi subagent **context-agent**
để khám phá codebase. Nếu working tree đang dirty, Claude dừng lại và yêu
cầu bạn commit/stash trước. Task cũng phải bắt đầu từ base branch được cấu
hình trong `.task/PROJECT.md` — nếu HEAD đang ở branch khác, Claude dừng
lại và yêu cầu bạn chuyển về base branch trước.

**Output:** `.task/overview.md` + `.task/context.md`, task branch được tạo, `.task/index.md` được cập nhật với branch mới.

**Verify trước khi sang Bước 2:**
- overview.md: đọc xong phần Goal, bạn có xác định được khi nào task "xong" không?
- context.md: data flow có khớp với kiến trúc thực tế không? Có phần Unknowns không?

---

## Bước 2 — AI web: planning

Mở một **cuộc hội thoại AI web mới**. Giữ cuộc hội thoại này mở trong suốt task.

Chạy `bin/copy-for-web.sh` (không tham số) — nó copy nội dung của
`PROJECT.md` + `overview.md` + `context.md` vào clipboard. Paste vào AI web kèm theo:

```
Dưới đây là project context, task overview, và technical context của một codebase.

[paste clipboard]

Hãy tạo một implementation plan chi tiết, từng bước.
Chỉ rõ chính xác file nào cần thay đổi và thay đổi là gì.
Chưa cần code — chỉ cần plan.
```

Review và tinh chỉnh trong AI web đến khi bạn hài lòng. Copy plan cuối cùng.

**Verify plan trước khi sang Bước 3:**
- Plan có nêu tên file cụ thể cho từng bước không?
- Plan có giải quyết mọi Acceptance Criterion trong overview.md không?

---

## Bước 3 — Claude Code: implement

**Khuyến nghị (tiết kiệm token):** copy plan từ AI web, sau đó từ root
project chạy:
```
pbpaste > .task/plan.md
```
(`pbpaste` dành cho macOS; trên Linux dùng `xclip -o > .task/plan.md` hoặc
`xsel -b > .task/plan.md`)

Sau đó chỉ cần nói với Claude:
```
plan đã lưu vào .task/plan.md, chạy execute
```
(dạng tiếng Anh `plan saved to .task/plan.md, run execute` vẫn hoạt động)

Main context không cần load toàn bộ plan vào cuộc hội thoại — chỉ
execute-agent đọc file này, tiết kiệm token.

**Fallback** (khi route clipboard không tiện) — paste trực tiếp, main
context sẽ ghi nó vào `.task/plan.md` giúp bạn:
```
triển khai plan này:
[paste plan từ AI web]
```
(dạng tiếng Anh `implement this plan: ...` vẫn hoạt động)

Dù theo cách nào, một khi `.task/plan.md` có plan, Claude sẽ gọi subagent
**execute-agent** để implement. execute-agent chạy Verify Command từ
`.task/PROJECT.md`, phải pass trước khi review.md được ghi — nếu không
pass, nó sẽ thử fix lại, hoặc dừng và báo cáo lỗi nếu không tự fix được.

**Output:** code thay đổi + `.task/review.md` (self-review) + `.task/testlog.md`
(scaffold Round 0) + một commit `round-0` (tag `round-0`) trên task branch.

**Nếu execute-agent dừng lại và escalate:** thay vì implement, agent có thể
dừng lại và báo cáo "phát hiện gì / vì sao plan chưa đủ / cần quyết định
gì" (ví dụ xung đột kiến trúc, hoặc plan mâu thuẫn với codebase thực tế).
Paste báo cáo đó vào cùng cuộc hội thoại AI web đang mở, yêu cầu nó revise
plan để giải quyết quyết định đó, rồi chạy lại Bước 3 với plan đã revise.

---

## Bước 4 — Test thủ công

Build app và test thật. Ghi kết quả vào `.task/testlog.md`
(scaffold `## Round 0` đã có sẵn — tick checklist và ghi chú vấn đề tìm thấy nếu có).

---

## Bước 5 — AI web: review

Quay lại **cuộc hội thoại AI web đang mở** (đã có plan từ Bước 2).

Chạy `bin/diff-for-web.sh` (không tham số) để copy toàn bộ diff của task
branch so với base branch vào clipboard.
Paste vào AI web kèm `.task/review.md`:

```
Đây là diff thực tế và self-review của Claude sau khi implement.

--- DIFF ---
[paste clipboard từ bin/diff-for-web.sh]

--- REVIEW ---
[paste toàn bộ nội dung .task/review.md]

--- MANUAL TEST RESULTS (if any) ---
[paste phần liên quan của .task/testlog.md, hoặc mô tả vấn đề tìm thấy]

So sánh diff với plan đã thống nhất ở trên: implementation có đúng, đủ, và
đúng phạm vi không? Liệt kê những gì cần fix. Nếu mọi thứ ổn, hãy nói rõ là
không cần fix gì thêm.
```

Plan đã có sẵn trong cuộc hội thoại này từ Bước 2, nên AI web dùng diff để
kiểm tra plan-vs-code — điều mà chỉ self-review không chứng minh được. Diff
là **bằng chứng**, review.md là **bản đồ** — dùng cả hai.

**Nếu AI web nói không cần fix gì → sang Bước 7.**
**Nếu AI web trả về fix list → sang Bước 6.**

---

## Bước 6 — Claude Code: fix (lặp tối đa 3 round)

**Khuyến nghị (tiết kiệm token):** copy fix list từ AI web, sau đó từ root
project chạy (thay `N` bằng số round thực tế):
```
printf '\n## Fix Notes — Round N\n\n' >> .task/review.md && pbpaste >> .task/review.md
```
`N` = (số heading `## Fix Notes — Round` đã có trong
`.task/review.md`) + 1 — cùng quy tắc main context dùng.

Sau đó chỉ cần nói với Claude (thay `N` bằng số round thực tế):
```
fix notes round N đã lưu, chạy fix
```
(dạng tiếng Anh `fix notes round N saved, run fix` vẫn hoạt động)

**Fallback** (khi route clipboard không tiện) — paste trực tiếp, main
context sẽ append nó vào `.task/review.md` giúp bạn:
```
sửa theo danh sách này:
[paste fix list từ AI web]
```
(dạng tiếng Anh `fix this list: ...` vẫn hoạt động)

Dù theo cách nào, một khi `## Fix Notes — Round N` xuất hiện trong
`.task/review.md`, Claude sẽ gọi subagent **fix-agent** để áp fix.
fix-agent cũng chạy Verify Command trước khi ghi kết quả.

**Output:** code fix + `## Fixes Applied — Round N` trong review.md +
scaffold `## Round N` mới trong testlog.md + một commit/tag `round-N` +
một **delta summary** ở cuối response.

**Vòng lặp:**
1. Test thủ công lại (Bước 4), ghi round tương ứng vào `.task/testlog.md`.
2. Chạy `bin/diff-for-web.sh N` — copy delta diff của round N (`round-{N-1}..round-N`).
   Nếu delta diff quá lớn, thu hẹp bằng `bin/diff-for-web.sh N --files path/to/File.swift`.
3. Quay lại AI web (cùng cuộc hội thoại) và paste **delta summary** + **delta diff** thay vì toàn bộ review.md.
4. Lặp lại Bước 6 → 4 → 5 đến khi AI web xác nhận không còn cần fix gì.

**Khi nào dừng:** vòng fix bị giới hạn tối đa **3 round**. Nếu round thứ 4
được yêu cầu, Claude dừng lại và yêu cầu bạn quyết định: chấp nhận nguyên
trạng, quay lại planning, hoặc thu hẹp phạm vi.

---

## Bước 7 — Claude Code: lưu task

Chỉ làm bước này khi AI web đã xác nhận không còn cần fix gì.

**Prompt:**
```
lưu task
```
(dạng tiếng Anh `save task` vẫn hoạt động)

Claude commit mọi thay đổi còn lại, archive toàn bộ file task vào
`.task/done/`, reset workspace (trừ `.task/PROJECT.md` — không bao giờ bị đụng tới),
và cập nhật `.task/index.md`.

Save **không tự squash hay tự merge** — đó là quyết định của bạn. Claude
báo cáo tên branch và gợi ý lệnh:

```
git checkout {base} && git merge --squash {branch} && git commit
```

Bạn nên merge branch này về base branch **trước khi bắt đầu task tiếp
theo** — Bước 1 của task tiếp theo chỉ chạy khi HEAD đang ở base branch
(overview sẽ dừng lại nếu không).

ID không còn bị trùng nữa, vì `overview` giờ quét cả các task branch hiện
có (kể cả chưa merge), không chỉ `.task/done/`.

---

## Cấu trúc thư mục

```
README.md              File này (tiếng Anh)
README.vi.md           Bản dịch tiếng Việt của file này
CLAUDE.md              Bảng agent routing + hard rules cho main context

bin/
  install-untracked.sh Cài workflow này vào project khác, gitignored (Option A)
  copy-for-web.sh       Copy PROJECT.md + overview.md + context.md vào clipboard (Bước 2)
  diff-for-web.sh       Copy git diff vào clipboard (Bước 5/6)

.claude/
  agents/
    context-agent.md   Khám phá codebase (subagent)
    execute-agent.md   Implement code (subagent)
    fix-agent.md       Fix bug (subagent)
  instructions/
    context.md         Hướng dẫn cho context-agent (không phải skill)
    execute.md         Hướng dẫn cho execute-agent (không phải skill)
    fix.md             Hướng dẫn cho fix-agent (không phải skill)
  skills/
    overview/          Phân tích yêu cầu + tạo branch (main context)
    save/              Archive task (main context)

.task/
  PROJECT.md            Project context + Verify Command + Git config (điền một lần, không agent nào ghi đè)
  index.md              Danh sách mọi task
  request.md            Yêu cầu gốc (tạo bởi skill overview)
  overview.md           Task spec (tạo bởi skill overview)
  context.md            Technical context riêng cho từng task (tạo bởi context-agent, sinh lại mỗi task)
  plan.md               Implementation plan (từ AI web)
  implementation.md     Tóm tắt implementation
  review.md             Self-review + lịch sử fix theo từng round
  testlog.md            Kết quả test thủ công theo từng round
  done/                 Archive các task đã hoàn thành
```

`.task/` **nên được commit** vào repo của project nếu cài qua Option B — đó
là bản ghi của task. Nếu cài qua Option A, `.task/` bị gitignore có chủ đích thay vào đó.
`bin/diff-for-web.sh` tự động loại trừ `.task/` khỏi diff để AI web chỉ thấy code thật.
