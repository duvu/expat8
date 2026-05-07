# Nghien cuu ho tro da ngon ngu: uu tien hoc tu vung tieng Trung

Ngay: 2026-05-06
Trang thai: Explore mode research (khong implementation)

## 1. Muc tieu

Can mo rong he thong hoc tu vung hien tai tu single-focus (thuc te dang nghien ve en/CEFR) sang multi-language, truoc mat ho tro hoc tieng Trung cho nguoi dung tieng Viet.

Muc tieu khong chi la doi target_language='zh', ma la dam bao:

- Du lieu tu vung phu hop ngon ngu co chu Han.
- Proficiency model khong bi khoa cung vao CEFR neu can dung HSK.
- Flow generation, validation, selection, study events, mobile rendering van on dinh.

## 2. Hien trang codebase (nhung gi da co san)

He thong da co nen tang multi-language theo ma ngon ngu:

- Backend va mobile deu truyen/nhan `source_language`, `target_language`, `language`.
- Data persistence da tach theo language trong `words`, `user_proficiency`, `user_word_states`, scheduler lock va generation run.
- Logic selection/scheduler dang chay theo target language, nen co the mo rong theo tung ngon ngu.

Dieu nay la diem rat tot: kien truc da co cot `language` xuyen suot, khong can dap di xay lai.

## 3. Cac rang buoc dang chua phu hop voi tieng Trung

### 3.1 Proficiency dang CEFR-centric

- Muc do hien tai dua tren CEFR A1-C2 (`proficiency.js`).
- Mobile state va UI thong diep level cung dang CEFR (`ProficiencyState`, `LearningSessionController`).
- OpenSpec cung ghi ro MVP mac dinh cho English theo CEFR.

Tac dong:

- Neu hoc tieng Trung, CEFR van co the dung tam thoi, nhung khong phai ngon ngu ban dia cho tieng Trung. HSK moi la thang do phu hop hon.

### 3.2 Chuan hoa term dang hardcode theo en-US

- `normalizeTerm()` dang `toLocaleLowerCase('en-US')`.

Tac dong:

- Với Hanzi, lowercase khong co y nghia.
- De duplicate va so sanh term/example co the sai lech voi ngon ngu khong co upper/lower case.

### 3.3 Validator dang gia dinh cau truc du lieu nghiêng English

`vocabulary_validator.js` dang buoc:

- `ipa` bat buoc.
- `vietnamese_pronunciation` bat buoc.
- `example` phai chua `term` sau normalize.
- `difficulty` phai map duoc CEFR.

Tac dong voi tieng Trung:

- IPA khong phai representation than thien nhat cho hoc vien Viet hoc Trung (pinyin thuong dung hon).
- Rule example chua term can than trong case segmentation/spacing/nghia da am/cum tu.

### 3.4 Prompt generation dang dong khung cho model English-centric

`litellm_client.js` dang mo ta item theo form:

- `meaning_vi`, `part_of_speech` in English, `ipa`, `vietnamese_pronunciation`, `example`, `example_vi`, `difficulty` CEFR.

Tac dong:

- Chua co truong pinyin, tone marks, hanzi variant (simplified/traditional).
- Chua co language profile de ra prompt khac nhau theo ngon ngu.

### 3.5 Mobile defaults va UX label

- Nhieu API call default `targetLanguage='en'`, `language='en'`.
- UI level-change message dang trung tinh theo level, nhung chua co display scale label theo language (VD: HSK 1-6).

Tac dong:

- Neu bat dau hoc zh, can dong bo cau hinh ngon ngu hoc hien tai cua user va hien thi scale dung context.

## 4. Ket luan nghien cuu: kien truc hop ly cho zh la gi?

### 4.1 Nen tan dung ha tang language-hien-co

Khong can tao he thong moi. Nen giu:

- Luong API hien tai.
- Cac bang da co cot `language`.
- Scheduler theo `target_language`.

Can thay doi o lop profile theo language va schema metadata cho tu vung.

### 4.2 Multi-language profile la trung tam

De xuat them mot concept logic: `LanguageProfile` (khong bat buoc implementation ngay), quy dinh theo tung ngon ngu:

- Proficiency scale: CEFR hay HSK.
- Field bat buoc cho generation/validation.
- Rule normalize term/example.
- Rule validation expression.

Vi du:

- en: CEFR, ipa preferred.
- zh-Hans: HSK, pinyin preferred, hanzi support.

## 5. De xuat cho tieng Trung (uu tien practical)

## 5.1 Proficiency strategy (chon huong 3)

Quyet dinh huong thiet ke:

1. Ho tro scale theo language trong toan bo flow ngay tu dau.
2. en su dung CEFR (A1-C2), zh su dung HSK (HSK1-HSK6).
3. Khong coi CEFR la internal source-of-truth cho zh.

Ly do:

- Trai nghiem nguoi hoc zh dung ngon ngu ban dia cua domain (HSK).
- Giam no ky thuat do map nguoc/forward CEFR<->HSK trong dai han.
- Tranh cac truong hop logic fallback/progression sai nghia khi scale khac nhau.

Phat bieu pham vi ro rang:

- Proficiency la cap doi `(scale, level)` thay vi chi mot string level.
- Selection, progression, API response, logging, mobile UI deu doc theo `(scale, level)`.

### 5.2 Data schema tu vung cho zh

Schema hien tai du cho MVP, nhung can metadata ngon ngu:

- term: cho hanzi (giu nhu hien tai).
- pronunciation: uu tien pinyin co tone.
- phonetic_system: vd `pinyin`, `ipa`.
- script_variant (tuy chon): `hans`/`hant`.

Neu chua muon doi DB ngay:

- Co the tai su dung `vietnamese_pronunciation` de luu pinyin tam thoi (giai phap transition).
- Nhưng ve trung han, nen doi ten/bo sung truong trung tinh ngon ngu de tranh ky thuat no.

### 5.2.1 Data shape de scale-native hoat dong on dinh

Can chuan hoa hop dong proficiency trong API/store:

- `proficiency.scale`: `cefr` | `hsk`
- `proficiency.level`: vd `A2` hoac `HSK3`
- `proficiency.level_index`: so thu tu trong scale (0-based hoac 1-based, can chot 1 quy uoc)

Quy tac de xuat:

- en => scale=`cefr`, levels=`A1,A2,B1,B2,C1,C2`
- zh => scale=`hsk`, levels=`HSK1,HSK2,HSK3,HSK4,HSK5,HSK6`
- Khong so sanh truc tiep `A2` voi `HSK3`; chi so sanh trong cung `scale`.

### 5.3 Validation rule theo language

Rule validate nen theo profile:

- zh: khong bat buoc IPA neu da co pinyin hop le.
- zh: rule `example` chua `term` can de o muc soft-check (warning) thay vi hard reject trong mot so truong hop.
- zh: validate difficulty/proficiency theo scale `hsk`.
- en: validate difficulty/proficiency theo scale `cefr`.

### 5.4 Prompt generation theo language template

Can prompt template rieng cho zh:

- term: hanzi.
- pronunciation: pinyin co dau thanh.
- meaning_vi: nghia tieng Viet.
- example: cau tieng Trung tu nhien, do dai vua phai.
- example_vi: ban dich tieng Viet.
- difficulty: HSK x (khong map tam qua CEFR).

Muc tieu: tranh ep model xuat IPA va POS theo style English cho zh.

### 5.5 Mobile UX cho zh

Can co `activeLearningLanguage` dong bo khi goi:

- fetchProficiency
- fetchNewWords
- submitStudyEvent

UI:

- Badge level hien `HSK x` neu zh, `A1...C2` neu en.
- Card co the hien them pinyin dong thu 2 duoi term.

Dong bo contract voi backend:

- Mobile luu state proficiency gom `scale` + `level`.
- Khi submit rating, mobile khong suy luan scale; chi render theo response backend.
- Khi doi ngon ngu hoc, mobile reset context theo cap `(target_language, scale, level)`.

## 6. Lo trinh de xuat (khong implementation)

### Phase A: Chot language-native proficiency contract

- Chot format proficiency response/request theo `(scale, level, level_index)`.
- Chot bang level cho tung language profile (en/cefr, zh/hsk).
- Cap nhat thiet ke progression/fallback chi trong cung scale.

### Phase B: Ap dung contract vao backend flow

- Selection doc proficiency theo scale profile.
- Study-event progression update theo scale profile (khong CEFR-hardcode).
- Validation/generation su dung template va rule theo language.

### Phase C: Ap dung contract vao mobile flow

- Mobile state, API parser, UI label doi sang scale-native.
- Hien thi dung level text theo language (HSK cho zh, CEFR cho en).
- Kiem thu multi-language switching va persistence theo language.

### Phase D: Schema cleanup va observability

- Chuyen field pronunciation sang language-neutral naming.
- Bo sung telemetry theo `target_language`, `scale`, `level`.
- Tao dashboard theo phan bo proficiency tren tung language.

## 7. Rui ro va giam thieu

Rui ro 1: Prompt output khong on dinh cho zh.
Giam thieu: Them validator + reject reason ro rang + telemetry theo language.

Rui ro 2: Duplicate term do normalize khong phu hop Hanzi.
Giam thieu: Normalize strategy per-language, test duplicate case cho zh.

Rui ro 3: UX level gay nham lan CEFR vs HSK.
Giam thieu: Response proficiency bo sung `scale` va mobile render theo `scale`.

Rui ro 5: Logic progression dang hardcode theo CEFR index co the vo tinh ap vao zh.
Giam thieu: Trich xuat progression engine theo language profile, test rieng cho en/zh.

Rui ro 4: Truong du lieu ten theo `vietnamese_pronunciation` gay no ky thuat khi them ngon ngu khac.
Giam thieu: Co migration plan sang field trung tinh, duy tri backward-compat trong 1-2 release.

## 8. De xuat OpenSpec tiep theo

Nen tao change OpenSpec moi, vi du: `support-language-native-proficiency-scales` voi pham vi uu tien:

- Stage 1: Introduce scale-native proficiency contract cho toan bo flow (API/store/mobile model).
- Stage 2: Enable zh day du tren contract moi (generation + selection + study-event + UI).
- Stage 3: Schema neutralization va quan sat van hanh.

Draft yeu cau cap cao:

- Backend phai sinh va luu duoc tu vung zh co pronunciation phu hop.
- Mobile phai hoc duoc the zh trong flow hien co ma khong pha vo en.
- Proficiency phai bieu dien duoc bang cap `(scale, level)` theo language profile.
- Telemetry/logging phai phan tach theo language de quan sat chat luong.

## 9. ASCII architecture sketch (muc tieu)

```text
                    +------------------------------+
                    | LanguageProfile Registry     |
                    | en -> CEFR / zh -> HSK      |
                    | normalize + validate rules   |
                    +---------------+--------------+
                                    |
         +--------------------------+---------------------------+
         |                          |                           |
+--------v--------+        +--------v--------+         +--------v--------+
| Prompt Builder  |        | Validator       |         | Proficiency      |
| per language    |        | per language    |         | per language     |
+--------+--------+        +--------+--------+         +--------+--------+
         |                          |                           |
         +--------------+-----------+---------------------------+
                        |
                 +------v------+
                 | words/store |
                 | language key|
                 +------+------+
                        |
                 +------v------+
                 | Mobile App  |
                 | render by   |
                 | language    |
                 +-------------+
```

## 10. Ket luan

He thong hien tai da co khung multi-language theo `language`, nen viec them tieng Trung la kha thi va co the di nhanh. Blocker chinh nam o 4 diem: CEFR-only, normalize en-US, validator/prompt English-centric, va default en o mobile.

Huong toi uu la dat scale-native lam nen tang ngay tu dau:

1. Chot va ap dung contract proficiency theo language (`cefr` cho en, `hsk` cho zh) trong toan bo flow.
2. Trien khai zh dua tren contract do, sau do clean-up schema va telemetry de mo rong ben vung sang cac ngon ngu khac.
