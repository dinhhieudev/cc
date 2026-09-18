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

## Cài đặt vào một dự án

### Phương án A — tự động, không track git

```
bash bin/install-untracked.sh [--lang en|vi] [--upgrade] /path/to/target
```

`<target-project-path>` phải đã tồn tại và là một git repository — script
dựa vào `.gitignore` để giữ mọi thứ nó cài đặt ngoài git status của dự án
đích. Nó sao chép:

- `.claude/agents/{context-agent.md,execute-agent.md,fix-agent.md}`
- `.claude/instructions/{context.md,execute.md,fix.md}`
- `.claude/skills/save/`
- `.task/` — chỉ khi dự án đích chưa có `.task/` (cài mới hoàn toàn; nếu đã
  có `.task/` thì giữ nguyên không đụng vào)
- `bin/{copy-for-web.sh,plan-prompt.md,result-prompt.md,save-plan.sh,save-followup.sh}`
  và `bin/lib/{copy-for-web-lib.sh,save-plan-lib.sh}`

Nó cũng gộp `CLAUDE.md` của repo này (bảng Agent Routing + các hard rules)
vào `CLAUDE.local.md` của dự án đích, giữa các marker comment, và thêm một
block tương ứng vào `.gitignore` của dự án đích để không có gì ở trên làm
bẩn lịch sử git chung.

Các cờ:
- `--lang en|vi` (cũng nhận `--lang=en`) — với bản cài mới, đặt `Language:`
  trong `.task/PROJECT.md` mới (mặc định `en`); bị bỏ qua nếu dự án đích đã
  có `.task/`, trừ khi dùng `--upgrade`, lúc đó dòng `Language:` vẫn được
  đồng bộ.
- `--upgrade` — cập nhật một bản cài không-track-git hiện có lên template
  hiện tại: ghi đè các file agent/instructions/skill/bin, xoá các đường dẫn
  đã bị loại bỏ ở bản cài cũ (`bin/diff-for-web.sh`,
  `.claude/skills/overview/`) nếu còn tồn tại, và làm mới các marker block
  trong `CLAUDE.local.md`/`.gitignore`. Yêu cầu đã có bản cài trước đó (kiểm
  tra marker trong `CLAUDE.local.md`) và không bao giờ đụng vào `.task/`
  ngoại trừ đồng bộ dòng `Language:`.

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
`## Important Files`, `## Known Constraints`, và `## Verify Command` — lệnh
shell chính xác (`npm run typecheck`, `swift build`, ...) mà execute-agent
và fix-agent phải chạy trước khi báo cáo hoàn thành. `## Language` mặc định
sẵn `Language: en`; đổi thành `vi` để xuất tiếng Việt. File này không bao
giờ bị agent hay skill nào sửa — bạn tự quản lý nó.

Khi `Language: vi`, `bin/copy-for-web.sh` nối thêm một dòng vào prompt web
(cả payload lập kế hoạch lẫn payload review kết quả) yêu cầu AI web trả lời
bằng tiếng Việt: "Write your response in Vietnamese (keep the ## headings
and file paths in English)."

## Bước 1 — Claude Code: task overview + context

Gõ `task: <yêu cầu>` (bí danh: `skill overview + context: <yêu cầu>`, hoặc
bất kỳ yêu cầu task mới nào bằng ngôn ngữ tự nhiên — tiếng Anh cũng dùng
được). Main context ghi yêu cầu của bạn nguyên văn vào `.task/overview.md`
dưới `## Original Request`, sau đó dispatch **context-agent**.

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
  `in-progress`)

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

Dán nội dung clipboard vào một cuộc hội thoại web **mới**, và đính kèm mọi
file mà `.task/web/` liệt kê. `bin/plan-prompt.md` yêu cầu model web hỏi lại
bạn trước nếu có điều gì mơ hồ quan trọng, nếu không thì tạo một kế hoạch
với sáu mục cố định: `## Summary`, `## Decisions to Review`,
`## AC Coverage`, `## Steps` (bảng `| # | File | Change | Notes |`),
`## Out of Scope`, `## Open Questions`. Bạn chỉ cần review ba mục đầu —
Summary, Decisions to Review, AC Coverage.

## Bước 3 — Claude Code: execute

Copy kế hoạch từ web chat, rồi chạy:

```
bin/save-plan.sh [--force]
```

Nó ghi nội dung clipboard vào `.task/plan.md`, và cảnh báo (không chặn) nếu
thiếu heading bắt buộc, còn `## Open Questions` chưa giải quyết, hoặc
`## Steps` tham chiếu đường dẫn file không tồn tại mà không được đánh dấu là
mới. Nó từ chối ghi đè `plan.md` đã có nội dung trừ khi có `--force`.

Sau đó bảo Claude `chạy execute` (hoặc `run execute`) — main context
dispatch thẳng **execute-agent** mà không tự đọc `plan.md`. Đường dẫn dự
phòng: dán thẳng kế hoạch vào cuộc hội thoại với `triển khai plan này:
<plan>` (hoặc `implement this plan: ...`), main context sẽ ghi nó vào
`.task/plan.md` trước.

execute-agent đọc `PROJECT.md`, `overview.md`, `plan.md`, đối chiếu
`## AC Coverage` với từng Acceptance Criterion, và dừng lại để báo cáo thay
vì đoán mò khi gặp một mục `## Open Questions` gây tắc nghẽn, xung đột kiến
trúc, hoặc bất cứ gì nhạy cảm về bảo mật. Nó triển khai `## Steps` theo thứ
tự, chạy `## Verify Command` từ `PROJECT.md` (tối đa 3 lần thử), và viết
`.task/implementation.md` (`## Changes`, `## Deviations from Plan`,
`## Verify`, `## Manual Test Checklist`), giới hạn ≤ 5.000 ký tự. Không
commit — workflow không đụng vào git.

## Bước 4 — kiểm thử và sửa (lặp lại, không giới hạn vòng)

Kiểm thử thủ công. Hai đường, lặp lại bao nhiêu lần tuỳ cần:

**Sửa nhỏ/rõ ràng** — nhắn thẳng cho Claude: `làm thêm: ...` / `fix: ...` /
`add: ...` (hoặc bất kỳ yêu cầu follow-up nào). Main context nối
`## Follow-up N` (yêu cầu của bạn, nguyên văn) vào `.task/followups.md`, rồi
dispatch **fix-agent**.

**Cần suy nghĩ thật sự** — chạy `bin/copy-for-web.sh result` trong *cùng*
web chat. Nó dựng payload từ `.task/implementation.md` và
`.task/followups.md` (nếu có nội dung), kèm prefix `bin/result-prompt.md`,
yêu cầu model web liệt kê các vấn đề so với plan/AC và, nếu cần follow-up,
xuất ra hướng dẫn follow-up chỉ-phần-thân sẵn để dán. Bạn có thể thêm kết
quả kiểm thử thủ công của riêng mình vào bên dưới báo cáo trước khi gửi.
Payload quá lớn sẽ tách FOLLOW-UPS rồi tới IMPLEMENTATION thành file đính
kèm trong `.task/web/`. Sau đó chạy `bin/save-followup.sh` (không tham số)
để nối clipboard thành `## Follow-up N` tiếp theo — nó cảnh báo nếu cái
trước chưa được đánh dấu Applied. Rồi bảo Claude `chạy fix` (hoặc
`run fix`) — main context dispatch **fix-agent** mà không tự đọc
`followups.md`.

fix-agent chỉ đọc mục `## Follow-up N` hiện tại (không đọc các vòng trước),
áp dụng thay đổi an toàn nhỏ nhất, chạy lại Verify Command (tối đa 3 lần
thử), và nối `## Follow-up N — Applied` — giới hạn ≤ 1.200 ký tự mỗi mục.

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
- reset năm file đó về template rỗng và xoá `.task/web/`
- không bao giờ đụng vào `.task/PROJECT.md`
- xoá mục Active Task trong `index.md` và thêm một dòng History

Không commit — bạn tự quản lý git; workflow không bao giờ stage hay commit
bất cứ gì.

## Giới hạn ký tự

Một tin nhắn web bị giới hạn `WEB_CHAR_LIMIT` (25.000 ký tự, override qua
biến môi trường):

| File / phần | Giới hạn |
|---|---|
| `.task/overview.md` | ≤ 4.000 ký tự |
| `.task/context.md` | ≤ 12.000 ký tự |
| `.task/implementation.md` | ≤ 5.000 ký tự |
| mỗi mục `## Follow-up N — Applied` | ≤ 1.200 ký tự |
| `.task/PROJECT.md` (điển hình) | ~5.000 ký tự |
| planning prompt (`bin/plan-prompt.md`) | ~2.500 ký tự |
| **Tổng mỗi tin nhắn web** | **25.000 ký tự** |

Phần nào không vừa sẽ được `bin/copy-for-web.sh` tách thành file đính kèm
trong `.task/web/` — tự bạn đính kèm chúng trong web chat.

## Cấu trúc thư mục

```
.
├── CLAUDE.md
├── README.md
├── README.vi.md
├── bin/
│   ├── copy-for-web.sh
│   ├── install-untracked.sh
│   ├── plan-prompt.md
│   ├── result-prompt.md
│   ├── save-followup.sh
│   ├── save-plan.sh
│   └── lib/
│       ├── copy-for-web-lib.sh
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
