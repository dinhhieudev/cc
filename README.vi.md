# Claude++ Workflow

[English](README.md) | Tiếng Việt

Một quy trình làm việc kết hợp một cuộc hội thoại AI trên web bên ngoài
(ChatGPT/Gemini — model mạnh hơn, quota riêng) với Claude Code (khám phá
codebase, triển khai, sửa lỗi). Web chat lo phần suy nghĩ: lập kế hoạch và
review kết quả. Claude Code thu thập context gọn và thực thi chính xác, trên
các subagent `sonnet` rẻ, để giữ mức tiêu tốn token của Claude ở mức thấp.

## Vì sao chia như vậy

Web chat là bộ não, có quota riêng tách biệt với Claude — nó đảm nhận việc
lập kế hoạch và review kết quả, phần suy luận nặng. Claude Code là đôi tay:
nó khám phá codebase, viết context kỹ thuật cô đọng, và thực thi kế hoạch
đúng theo chữ, qua các subagent rẻ. Không có git diff nào được gửi lên web
chat, và bản thân workflow không bao giờ đụng vào git — branch và commit
hoàn toàn do con người quyết định.

Mọi thứ gửi lên web chat đều bị giới hạn số ký tự (một tin nhắn web tối đa
`WEB_CHAR_LIMIT`, mặc định 25.000 ký tự), phần nào không vừa sẽ được tách
thành file đính kèm trong `.task/web/` để bạn tự đính kèm.

**Bình thường vs `--lean` (Bước 1):**

| Codebase | Đường dẫn |
|---|---|
| Lớn hoặc chưa quen | Bình thường (`task: ...`) — `context.md` đầy đủ hơn cho planner |
| Nhỏ, hoặc bạn đã biết rõ khu vực | `--lean` (`task (lean): ...`) — tiết kiệm token Claude, đổi lại một vòng qua lại thêm |

**Sửa trực tiếp vs vòng qua web (follow-up ở Bước 4):**

| Follow-up | Đường dẫn |
|---|---|
| Lỗi nhỏ, rõ ràng, bạn đã biết cách mô tả | Nhắn thẳng cho Claude: `fix: ...` |
| Lỗi chưa rõ, hoặc plan còn thiếu gì đó cần cân nhắc | Đi qua web: `bin/copy-for-web.sh result` |

## Cài đặt vào một dự án

### Phương án A — tự động, không track git

```
bash bin/install-untracked.sh [--lang en|vi] [--upgrade] /path/to/target
```

`<target-project-path>` phải đã tồn tại và là một git repository — script
dựa vào `.git/info/exclude` (chỉ tồn tại cục bộ) của dự án đích để giữ mọi
thứ nó cài đặt ngoài git status của dự án đích. Nó sao chép:

- `.claude/agents/{context-agent.md,execute-agent.md,fix-agent.md}`
- `.claude/instructions/{context.md,execute.md,fix.md}`
- `.claude/skills/save/`
- `.task/` — chỉ khi dự án đích chưa có `.task/` (cài mới hoàn toàn; nếu đã
  có `.task/` thì giữ nguyên không đụng vào)
- `bin/{copy-for-web.sh,plan-prompt.md,result-prompt.md,save-plan.sh,save-followup.sh,attach.sh,lean-note.md}`
  và `bin/lib/{copy-for-web-lib.sh,copy-for-web-design.sh,copy-for-web-result.sh,copy-for-web-modes.sh,copy-for-web-lean.sh,copy-for-web-handoff.sh,save-plan-lib.sh}`

Nó cũng gộp `CLAUDE.md` của repo này (bảng Agent Routing + các hard rules)
vào `CLAUDE.local.md` của dự án đích, giữa các marker comment, và thêm một
block tương ứng vào `.git/info/exclude` của dự án đích — không bao giờ vào
`.gitignore` (file có track git) — để không có gì ở trên làm bẩn lịch sử
git chung. `.git/info/exclude` chỉ tồn tại cục bộ trên máy (không được
đồng bộ), nên hãy chạy lại trình cài đặt sau khi clone dự án đích sang máy
khác. Nếu bản cài trước để lại một block claude++ trong `.gitignore` của
dự án đích, mỗi lần chạy sẽ xoá block đó (phần còn lại của file giữ
nguyên) và nhắc bạn commit việc xoá này một lần nếu block đó từng được
commit.

Các cờ:
- `--lang en|vi` (cũng nhận `--lang=en`) — với bản cài mới, đặt `Language:`
  trong `.task/PROJECT.md` mới (mặc định `en`); bị bỏ qua nếu dự án đích đã
  có `.task/`, trừ khi dùng `--upgrade`, lúc đó dòng `Language:` vẫn được
  đồng bộ.
- `--upgrade` — cập nhật một bản cài không-track-git hiện có lên template
  hiện tại: ghi đè các file agent/instructions/skill/bin, xoá các đường dẫn
  đã bị loại bỏ ở bản cài cũ (`bin/diff-for-web.sh`,
  `.claude/skills/overview/`) nếu còn tồn tại, và làm mới các marker block
  trong `CLAUDE.local.md`/`.git/info/exclude`. Yêu cầu đã có bản cài trước
  đó (kiểm tra marker trong `CLAUDE.local.md`) và không bao giờ đụng vào
  `.task/` ngoại trừ đồng bộ dòng `Language:`.

Nếu `.claude/agents/*` hoặc `.claude/skills/save/` đã tồn tại ở dự án đích
với nội dung khác, script sẽ dừng trước khi copy bất cứ gì, trừ khi có
`--upgrade` — xem Phương án B, mục c) bên dưới.

### Phương án B — thủ công, có track git

Dùng khi bạn muốn commit các file workflow vào repo đích thay vì gitignore
chúng.

#### a) Cần copy những gì

Cùng danh sách file như Phương án A ở trên, cộng thêm toàn bộ `.task/`
(`PROJECT.md`, `overview.md`, `context.md`, `plan.md`, `implementation.md`,
`followups.md`, `index.md`, `done/README.md`). Lưu ý `bin/install-untracked.sh`
và `bin/lib/install-untracked-lib.sh` là bản thân trình cài đặt, không thuộc
về workflow — đừng copy hai file này.

Tự bạn commit các file đã copy vào repo đích; workflow không bao giờ làm
việc đó thay bạn. Cân nhắc gitignore `.task/web/` ở dự án đích — đây là thư
mục tạm mà `bin/copy-for-web.sh` dựng lại mỗi lần chạy và `save` xoá khi một
task được lưu trữ.

#### b) Gộp khi dự án đích đã có CLAUDE.md

Dán bảng Agent Routing và mục "Hard rules for main context" của repo này
vào `CLAUDE.md` của dự án đích (hoặc thêm chúng như một mục mới).

#### c) Gộp khi dự án đích đã có `.claude/agents/` hoặc `.claude/skills/`

Đổi tên một bên (các file `context-agent`/`execute-agent`/`fix-agent` hoặc
`save` của workflow này, hoặc các file đã có sẵn ở dự án đích) để tên không
trùng nhau, rồi cập nhật mọi nơi tham chiếu tới tên cũ.

#### d) Kiểm tra bản cài

Từ thư mục gốc dự án đích: `bin/copy-for-web.sh --help` phải in ra hướng
dẫn sử dụng, và `.task/PROJECT.md` phải tồn tại, sẵn sàng để điền.

## Thiết lập ban đầu (chỉ một lần)

Điền vào `.task/PROJECT.md`: `## Project`, `## Tech Stack`,
`## Architecture Overview`, `## Key Conventions`, `## Source Layout`,
`## Important Files`, `## Known Constraints`, và các lệnh verify —
`## Codegen / Setup Command` (sinh code hoặc tải dependency, chạy trước
type check khi thay đổi đụng tới model, dependency, chuỗi l10n, hoặc
asset — vd: `dart run build_runner build`, `pod install`),
`## Type Check Command` (nhanh, bắt buộc), `## Build Command` (bị gán
bởi một dòng tuỳ chọn `Build policy: native-only|always|never`, mặc
định `native-only` — chỉ build khi thay đổi đụng tới cấu hình native,
dependency, codegen, file platform, hoặc build settings), `## Test
Command`, và `## Device Smoke Test Command`. Ba mục cuối nhận một lệnh
duy nhất hoặc một dòng cho mỗi platform (`ios: ...` / `android: ...`);
khi task đụng tới cả hai, iOS chạy trước và Android chỉ chạy nếu thay
đổi là đặc thù Android. `## Language` mặc định sẵn `Language: en`; đổi
thành `vi` để xuất tiếng Việt. File này không bao giờ bị agent nào sửa;
chỉ skill `save` mới được nối thêm các gợi ý bạn đã duyệt ở Bước 5 —
ngoài ra bạn tự quản lý nó.

Khi `Language: vi`, `bin/copy-for-web.sh` nối thêm một dòng vào prompt web
(cả payload lập kế hoạch lẫn payload review kết quả) yêu cầu AI web trả lời
bằng tiếng Việt: "Write your response in Vietnamese (keep the ## headings
and file paths in English)."

### Human-runs profile (không tự động build/run)

Khi con người tự lo build/run/kiểm thử thủ công — các agent Claude không
bao giờ chạy build hay khởi chạy app; con người tự build, chạy, kiểm thử
thủ công, rồi báo lại vấn đề — hãy đặt `Build policy: never`, để trống
`## Device Smoke Test Command`, và vẫn điền `## Codegen / Setup Command`
cùng `## Type Check Command`. Codegen vẫn chạy (`build_runner`,
`pod install`, `gen-l10n`) vì type check phụ thuộc vào file được sinh ra
— bước này không thể bỏ qua.

| Project | Type Check Command | Test Command | Build policy |
|---|---|---|---|
| Flutter | `dart analyze` | `flutter test` | `never` |
| Android native | `./gradlew compileDebugKotlin` | `./gradlew testDebugUnitTest` | `never` |
| Android KMP | `./gradlew compileKotlinJvm` | `./gradlew jvmTest` | `never` |
| iOS native | `xcodebuild build -scheme <Scheme> -destination 'generic/platform=iOS' -quiet` | `swift test` for SPM logic packages, else empty | `never` |

Chọn lệnh test KHÔNG boot simulator hay emulator. Với KMP, tránh
`./gradlew allTests` — nó kéo theo cả target iOS và boot simulator.

- `generic/platform=iOS` build theo kiến trúc thiết bị thật và không bao
  giờ boot simulator. Đây là một lần compile đầy đủ, nên lần chạy đầu
  (cold) mất vài phút, nhưng các lần chạy sau (warm, incremental) chỉ
  khoảng 20-60s nhờ derived-data cache.
- Chỉ `xcodebuild test` nhắm vào một test target riêng cho iOS mới cần
  boot simulator. Logic nằm trong một SwiftPM package không phụ thuộc
  platform có thể test bằng `swift test` ngay trên máy macOS — vài giây,
  không cần simulator.

iOS native không có type check *rẻ* — cái rẻ nhất đúng nghĩa là một
incremental build đầy đủ, khác với `dart analyze` hay
`compileDebugKotlin`. Nếu chấp nhận được chi phí đó, hãy đặt build
`generic/platform=iOS` vào ô Type Check và iOS native được phủ như ba
project còn lại. Nếu không, để trống Type Check và chấp nhận không có
xác minh tự động nào: execute-agent khi đó phải nêu rõ trong
`.task/implementation.md` rằng không có lệnh verify nào được cấu hình,
thay vì âm thầm bỏ qua, và lớp bảo vệ tự động còn lại duy nhất là quy tắc
escalation (một dependency, permission, entitlement, hoặc thay đổi
Info.plist/AndroidManifest mới không có trong plan sẽ chặn agent lại).
Lưu ý thêm: dùng chung DerivedData mặc định với một Xcode đang mở có thể
gây tranh chấp khoá (lock contention) — truyền `-derivedDataPath` trỏ tới
một thư mục riêng nếu gặp vấn đề này.

## Bước 1 — Claude Code: task overview + context

Gõ `task: <yêu cầu>` (bí danh: `skill overview + context: <yêu cầu>`, hoặc
bất kỳ yêu cầu task mới nào bằng ngôn ngữ tự nhiên — tiếng Anh cũng dùng
được). Main context ghi yêu cầu của bạn nguyên văn vào `.task/overview.md`
dưới `## Original Request`, sau đó dispatch **context-agent**.

Ví dụ: `task: add a dark-mode toggle to the settings screen`. (Ví dụ này
sẽ xuyên suốt Bước 1-5 bên dưới.)

context-agent đọc `.task/PROJECT.md` và `.task/overview.md`, khám phá
codebase (qua CodeGraph nếu dự án đích có `.codegraph/`), rồi viết:

- `.task/overview.md` — spec đầy đủ (`## Goal`, `## Problem`, `## Scope`,
  `## Out of Scope`, `## Requirements`, `## Constraints`,
  `## Acceptance Criteria`, `## Ambiguities`, `## Notes`), giới hạn ≤ 4.000
  ký tự
- `.task/context.md` — context kỹ thuật cho người lập kế hoạch (`## Relevant
  Architecture`, `## Relevant Files`, `## Existing Patterns`,
  `## Data Flow`, `## Dependencies`, `## Current Behavior`,
  `## Important Constraints`, `## Potential Risk Areas`,
  `## Relevant Code Snippets`, `## Unknowns`, `## Files to Attach` — tối đa
  10 đường dẫn), giới hạn ≤ 12.000 ký tự
- `.task/index.md` — mục Active Task (ID, Name, Started, Status =
  `spec`). Status sau đó tiến triển: `planned` khi `bin/save-plan.sh` lưu
  plan, `executing` khi execute-agent bắt đầu, `fixing` khi một vòng
  follow-up bắt đầu, `done` khi task được lưu.

**Đường dẫn lean** — cho dự án nhỏ, hoặc khi bạn đã biết rõ khu vực cần sửa: gõ
`task (lean): <yêu cầu>` (bí danh: `task lean: <yêu cầu>`) thay vì `task:`. context-agent
chỉ viết `.task/overview.md` (spec đầy đủ như bình thường, cùng giới hạn ký tự) từ
`.task/PROJECT.md`, yêu cầu của bạn, và tối đa 3 file bạn nêu rõ tên — nó không khám phá
codebase ngoài phạm vi đó, và để nguyên `.task/context.md` ở dạng template rỗng. Cách này
tiết kiệm token Claude, đổi lại một vòng qua lại thêm với web planner; với codebase lớn và
chưa quen, đường bình thường với `context.md` cho planner ngữ cảnh tốt hơn, nên ưu tiên
dùng đường đó. Tiếp tục ở Bước 2 với `bin/copy-for-web.sh --lean` thay vì dạng thường.

**Ảnh thiết kế tham khảo (tùy chọn)** — bỏ ảnh chụp màn hình tham khảo cho một task UI vào
`.task/design/` bất cứ lúc nào trước Bước 2; `bin/copy-for-web.sh` (plan mode) tự động đính
kèm chúng (xem Bước 2). Claude Code không bao giờ tự mở các ảnh này, chỉ chuyển tiếp — AI
web planner mới là bên đọc trực tiếp. Nếu bạn đưa context-agent một link Figma và dự án có
cấu hình Figma MCP, nó sẽ trích một mô tả dạng văn bản vào mục CONTEXT của
`.task/context.md` như bình thường (Figma MCP là tùy chọn; bỏ qua nhẹ nhàng nếu không có).

## Bước 2 — AI web: lập kế hoạch

Chạy:

```
bin/copy-for-web.sh [--split]
```

Không có tham số, nó dựng payload lập kế hoạch — `.task/PROJECT.md` (nếu có
nội dung thực ngoài dòng Language), `.task/overview.md`, `.task/context.md`,
kèm prefix là `bin/plan-prompt.md` — và copy vào clipboard. Nếu payload vượt
`WEB_CHAR_LIMIT` (mặc định 25.000, có thể override qua biến môi trường),
CONTEXT bị tách thành file đính kèm trong `.task/web/` trước, rồi tới
PROJECT nếu vẫn còn vượt; `--split` ép cả hai thành file đính kèm bất kể
kích thước. Một cảnh báo (kèm bảng chi tiết kích thước từng phần) sẽ in ra
khi đạt 85% giới hạn.

Nếu `.task/design/` có ảnh chụp màn hình tham khảo, chúng cũng được tự động đính kèm theo
cách tương tự (liệt kê dưới `--- DESIGN REFERENCE (attached) ---`) — đính kèm luôn cả những
file đó. `bin/plan-prompt.md` yêu cầu web planner đối chiếu từng ảnh với mô tả từ Figma (nếu
có) trong CONTEXT và nêu rõ chỗ không khớp thành một mục Decision to Review hoặc Open
Question; nếu không có mô tả nào, ảnh là nguồn tham khảo chính cho layout.

Dán nội dung clipboard vào một cuộc hội thoại web **mới**, và đính kèm mọi
file mà `.task/web/` liệt kê. `bin/plan-prompt.md` yêu cầu model web hỏi lại
bạn trước nếu có điều gì mơ hồ quan trọng, nếu không thì tạo một kế hoạch
với sáu mục cố định: `## Summary`, `## Decisions to Review`,
`## AC Coverage`, `## Steps` (bảng `| # | File | Change | Notes |`),
`## Out of Scope`, `## Open Questions`. Bạn chỉ cần review ba mục đầu —
Summary, Decisions to Review, AC Coverage.

Với ví dụ dark-mode, một đoạn trích minh hoạ (không phải format bắt buộc)
của những gì trả về có thể trông như sau:

```
## Decisions to Review
- Persist the toggle via SharedPreferences, not a new state-management
  provider — avoids adding a dependency for a single boolean.

## AC Coverage
- AC1 (toggle visible in Settings): Step 1
- AC2 (persists across restarts): Step 1

## Steps
| # | File | Change | Notes |
|---|---|---|---|
| 1 | lib/settings/settings_screen.dart | Add dark-mode Switch, wire to ThemeProvider | persists via SharedPreferences |
```

**Đường dẫn lean** — sau `bin/copy-for-web.sh --lean` (xem Bước 1), payload thay
`.task/context.md` bằng một FILE TREE của dự án (`git ls-files`, hoặc `find` đã lọc bớt
nếu không phải git repo) và thêm `bin/lean-note.md` vào prompt, yêu cầu web planner trả
lời trước danh sách file nó cần (tối đa 15 đường dẫn từ cây file) trước khi ra kế hoạch.
Chạy `bin/attach.sh <path> [<path>...]` để copy các file đó vào `.task/web/` (làm phẳng
tên, in ra bảng ánh xạ và tổng số ký tự; cũng nhận `-` để đọc đường dẫn từ stdin), đính
kèm chúng trong cùng web chat, rồi xin kế hoạch — sau đó tiếp tục ở Bước 3 như bình
thường. FILE TREE quá lớn sẽ giảm dần: file gây nhiễu (lockfile, ảnh, `*.min.*`,
`.task/**`) bị loại trước, rồi gộp thành số đếm theo thư mục `dir/ (N files)`, rồi đính
kèm toàn bộ cây dưới dạng `.task/web/file-tree.txt`; `--split` ép cả FILE TREE lẫn
PROJECT thành file đính kèm ngay.

Vòng qua lại cụ thể: `task (lean): add a dark-mode toggle to the settings
screen`, rồi `bin/copy-for-web.sh --lean`. Web có thể trả lời bằng một danh
sách minh hoạ (giả định) như:

```
1. lib/settings/settings_screen.dart
2. lib/theme/theme_provider.dart
```

Sau đó `bin/attach.sh lib/settings/settings_screen.dart lib/theme/theme_provider.dart`
in ra:

```
lib/settings/settings_screen.dart -> lib__settings__settings_screen.dart
lib/theme/theme_provider.dart -> lib__theme__theme_provider.dart
Total chars now in .task/web: 3214
```

Đính kèm cả hai file trong web UI, xin kế hoạch, rồi tiếp tục ở Bước 3.

## Bước 3 — Claude Code: execute

Mặc định: copy kế hoạch từ web chat rồi dán thẳng vào cuộc hội thoại với
`triển khai plan này: <plan>` (hoặc `implement this plan: ...`, hoặc chỉ dán
nguyên văn kế hoạch). Claude ghi nó nguyên văn vào `.task/plan.md` (ghi đè
bất cứ gì đang có), chạy `bin/save-plan.sh --check` để kiểm tra, báo lại
cảnh báo (nếu có) trong một hai dòng, rồi vẫn dispatch **execute-agent** —
cảnh báo chỉ mang tính thông tin, không chặn.

Đường dẫn rẻ hơn, nếu bạn muốn kế hoạch không bao giờ vào cuộc hội thoại
Claude: copy kế hoạch từ web chat, rồi chạy:

```
bin/save-plan.sh [--force] | --stdin [--force] | --check
```

Không có cờ, nó đọc clipboard và ghi vào `.task/plan.md`, chạy cùng bộ kiểm
tra, và cảnh báo (không chặn) nếu thiếu heading bắt buộc, còn
`## Open Questions` chưa giải quyết, mục `## Decisions to Review` quá sơ
sài (chỉ toàn gạch đầu dòng ngắn, không thấy lý lẽ), hoặc `## Steps` tham
chiếu đường dẫn file không tồn tại mà không được đánh dấu là mới. Nó từ chối ghi đè
`plan.md` đã có nội dung trừ khi có `--force`. `--stdin` đọc kế hoạch từ
stdin thay vì clipboard (vd: `cat plan.txt | bin/save-plan.sh --stdin`) và
còn lại giống hệt đường clipboard. `--check` kiểm tra `.task/plan.md` hiện
có tại chỗ — không đọc clipboard, không ghi gì — chỉ báo lỗi nếu file thiếu
hoặc vẫn còn là placeholder.

Sau đó bảo Claude `chạy execute` (hoặc `run execute`) — main context dispatch
thẳng **execute-agent** mà không tự đọc `plan.md`.

execute-agent đọc `PROJECT.md`, `overview.md`, `plan.md`, đối chiếu
`## AC Coverage` với từng Acceptance Criterion, và dừng lại để báo cáo thay
vì đoán mò khi gặp một mục `## Open Questions` gây tắc nghẽn, xung đột kiến
trúc, bất cứ gì nhạy cảm về bảo mật, hoặc một dependency/permission/
entitlement/thay đổi manifest mới mà plan không liệt kê. Nó triển khai
`## Steps` theo thứ tự, rồi chạy codegen/setup (khi cần), type check,
build (bị gán bởi `Build policy:`), và test/device smoke — mỗi platform
một lệnh khi có cấu hình, iOS trước — tối đa 3 lần thử, và viết
`.task/implementation.md` (`## Changes`, `## Deviations from Plan`,
`## Verify`, `## Manual Test Checklist`, `## PROJECT.md Candidates`), giới
hạn ≤ 6.000 ký tự. Với task UI, Manual Test Checklist yêu cầu bạn lưu ảnh
kết quả vào `.task/design/result/`. Không commit — workflow không đụng
vào git.

Với ví dụ dark-mode, một dòng `## Changes` minh hoạ:
`- lib/settings/settings_screen.dart: added dark-mode toggle, persists via SharedPreferences`

## Bước 4 — kiểm thử và sửa (lặp lại, không giới hạn vòng)

Kiểm thử thủ công. Hai đường, lặp lại bao nhiêu lần tuỳ cần:

**Sửa nhỏ/rõ ràng** — nhắn thẳng cho Claude: `làm thêm: ...` / `fix: ...` /
`add: ...` (hoặc bất kỳ yêu cầu follow-up nào). Main context nối
`## Follow-up N` (yêu cầu của bạn, nguyên văn) vào `.task/followups.md`, rồi
dispatch **fix-agent**.

Với ví dụ dark-mode, giả sử test phát hiện lỗi: `fix: toggling twice
re-triggers the API call`. fix-agent sửa lỗi rồi nối `## Follow-up 1 —
Applied` vào `.task/followups.md`.

Nếu kiểm thử thủ công phát hiện crash, tự bạn lấy log —
`xcrun simctl spawn booted log show --last 2m` cho iOS, `adb logcat -d`
cho Android — rồi hoặc dán khoảng 30 frame đầu vào yêu cầu `fix: ...`
(đường trực tiếp), hoặc ghi ra file và chạy `bin/attach.sh <file>` để
gửi kèm vòng qua web bên dưới.

**Cần suy nghĩ thật sự** — chạy `bin/copy-for-web.sh result` trong *cùng*
web chat. Nó dựng payload từ `.task/implementation.md` và
`.task/followups.md` (nếu có nội dung), kèm prefix `bin/result-prompt.md`,
yêu cầu model web liệt kê các vấn đề so với plan/AC và, nếu cần follow-up,
xuất ra hướng dẫn follow-up chỉ-phần-thân sẵn để dán. Bạn có thể thêm kết
quả kiểm thử thủ công của riêng mình vào bên dưới báo cáo trước khi gửi.
Nếu bạn đã lưu ảnh vào `.task/design/result/`, chúng được tự động đính kèm
(liệt kê dưới `--- RESULT SCREENSHOTS (attached) ---`) và được
`bin/result-prompt.md` đối chiếu với ảnh thiết kế tham khảo. Thêm `--diff`
để đính kèm luôn một `git diff` đã lọc (thay đổi tracked + untracked,
loại trừ `.task/`, lockfile, `.pbxproj`, và file sinh tự động) dưới dạng
`.task/web/changes.diff.txt`, giới hạn `WEB_DIFF_MAX_BYTES` (mặc định
100.000 byte) — mặc định tắt vì diff thường quá dài; nó cảnh báo thay vì
báo lỗi khi không phải git repo hoặc không có gì để diff. Payload quá lớn
sẽ tách FOLLOW-UPS rồi tới IMPLEMENTATION thành file đính
kèm trong `.task/web/`. Sau đó chạy `bin/save-followup.sh` (không tham số)
để nối clipboard thành `## Follow-up N` tiếp theo — nó cảnh báo nếu cái
trước chưa được đánh dấu Applied. Rồi bảo Claude `chạy fix` (hoặc
`run fix`) — main context dispatch **fix-agent** mà không tự đọc
`followups.md`.

fix-agent chỉ đọc mục `## Follow-up N` hiện tại (không đọc các vòng trước),
áp dụng thay đổi an toàn nhỏ nhất, chạy lại Verify Command (tối đa 3 lần
thử), và nối `## Follow-up N — Applied` — giới hạn ≤ 1.400 ký tự mỗi mục.

**Chat mới** — nếu web chat *cùng* cuộc hội thoại ở trên đã quá dài hoặc mất
ngữ cảnh, chạy `bin/copy-for-web.sh handoff` thay vì `result` rồi dán vào
một web chat **mới**. Nó gửi một đoạn giới thiệu ngắn cùng OVERVIEW SUMMARY
(`## Goal` + `## Acceptance Criteria`), bảng `## Steps` của plan, và vòng
Follow-up mới nhất (hoặc phần Changes/Deviations của `implementation.md`),
yêu cầu web xác nhận đã hiểu trước khi tiếp tục — không cần gõ lại ngữ cảnh
ban đầu. Payload quá lớn sẽ tách OVERVIEW SUMMARY rồi tới CURRENT PLAN STEPS
thành file đính kèm trong `.task/web/`. Tiếp tục vòng lặp ở trên trong chat
mới đó.

Dấu hiệu cụ thể: sau 4-5 vòng follow-up trong cùng web chat, câu trả lời
bắt đầu chậm hơn hoặc mất chi tiết trước đó — đó là lúc nên chạy
`bin/copy-for-web.sh handoff`.

## Bước 5 — Claude Code: lưu task

Gõ `lưu task` (hoặc `save task`). Skill `save`:

- chặn lại nếu có `## Follow-up N` nào chưa có `## Follow-up N — Applied`
  tương ứng, trừ khi bạn xác nhận rõ ràng muốn lưu trữ trạng thái dở dang
- xác định id/slug của task từ mục Active Task trong `.task/index.md` (hoặc
  tự suy ra từ Goal trong `overview.md` cộng số thư mục con trong
  `.task/done/`)
- tiếp tục một lần lưu trữ bị gián đoạn nếu `.task/done/{id}-{slug}/` đã
  tồn tại với cùng Goal
- copy `overview.md`, `context.md`, `plan.md`, `implementation.md`,
  `followups.md` vào `.task/done/{id}-{slug}/`
- cho bạn xem các gợi ý `## PROJECT.md Candidates` từ `implementation.md`
  và các dòng `PROJECT.md candidate` từ `followups.md`, rồi chỉ nối vào
  `.task/PROJECT.md` những mục bạn duyệt — đây là ngoại lệ duy nhất so với
  việc không bao giờ đụng vào file này
- reset năm file đó về template rỗng và xoá `.task/web/`
- xoá mục Active Task trong `index.md` và thêm một dòng History

Với ví dụ dark-mode, một gợi ý candidate có thể là: "Key Conventions:
dark-mode state persists via SharedPreferences, not a global provider" —
bạn trả lời `add it` để duyệt, hoặc `skip` để từ chối.

Không commit — bạn tự quản lý git; workflow không bao giờ stage hay commit
bất cứ gì.

## Giới hạn ký tự

Một tin nhắn web bị giới hạn `WEB_CHAR_LIMIT` (25.000 ký tự, override qua
biến môi trường):

| File / phần | Giới hạn |
|---|---|
| `.task/overview.md` | ≤ 4.000 ký tự |
| `.task/context.md` | ≤ 12.000 ký tự |
| `.task/implementation.md` | ≤ 6.000 ký tự |
| mỗi mục `## Follow-up N — Applied` | ≤ 1.400 ký tự |
| `.task/PROJECT.md` (điển hình) | ~5.000 ký tự |
| planning prompt (`bin/plan-prompt.md`) | ~3.500 ký tự |
| **Tổng mỗi tin nhắn web** | **25.000 ký tự** |

Phần nào không vừa sẽ được `bin/copy-for-web.sh` tách thành file đính kèm
trong `.task/web/` — tự bạn đính kèm chúng trong web chat.

Mỗi lần chạy `bin/copy-for-web.sh` cũng ghi nguyên văn payload vào
`.task/web/_message.md` — dán tay khi điều khiển phiên làm việc từ xa,
không có clipboard.

## Cấu trúc thư mục

```
.
├── CLAUDE.md
├── README.md
├── README.vi.md
├── bin/
│   ├── attach.sh
│   ├── copy-for-web.sh
│   ├── install-untracked.sh
│   ├── lean-note.md
│   ├── plan-prompt.md
│   ├── result-prompt.md
│   ├── save-followup.sh
│   ├── save-plan.sh
│   └── lib/
│       ├── copy-for-web-design.sh
│       ├── copy-for-web-handoff.sh
│       ├── copy-for-web-lean.sh
│       ├── copy-for-web-lib.sh
│       ├── copy-for-web-modes.sh
│       ├── copy-for-web-result.sh
│       ├── install-untracked-lib.sh
│       └── save-plan-lib.sh
├── .claude/
│   ├── agents/
│   │   ├── context-agent.md
│   │   ├── execute-agent.md
│   │   └── fix-agent.md
│   ├── instructions/
│   │   ├── context.md
│   │   ├── execute.md
│   │   └── fix.md
│   └── skills/
│       └── save/
│           └── SKILL.md
└── .task/
    ├── PROJECT.md
    ├── overview.md
    ├── context.md
    ├── plan.md
    ├── implementation.md
    ├── followups.md
    ├── index.md
    ├── web/            (tạm — dựng lại mỗi lần chạy copy-for-web.sh, bị xoá bởi save)
    └── done/
        ├── README.md
        └── {id}-{slug}/
```
