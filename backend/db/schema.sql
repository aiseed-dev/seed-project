-- =====================================================================
-- 種の交換アプリ / 伝統野菜辞典 共有スキーマ
-- PostgreSQL 15+
--
-- スキーマ構成:
--   shared     … 3アプリ共有(ユーザー・分類・品種マスタ)
--   exchange   … 種の交換アプリ
--   dictionary … 伝統野菜辞典アプリ
--   (recipe    … 伝統料理辞典。将来追加)
--
-- 認証は PocketBase。shared.app_users.id に PocketBase の
-- レコードIDを格納する。メールアドレス・パスワードは持たない。
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS shared;
CREATE SCHEMA IF NOT EXISTS exchange;
CREATE SCHEMA IF NOT EXISTS dictionary;

-- updated_at 自動更新トリガの関数(各テーブルのトリガより先に定義する)
CREATE OR REPLACE FUNCTION shared.touch_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- shared: ユーザー(PocketBaseの身元に対応する業務プロフィール)
-- ---------------------------------------------------------------------
CREATE TABLE shared.app_users (
    id            TEXT PRIMARY KEY,          -- PocketBase record id
    display_name  TEXT NOT NULL,
    region        TEXT,                      -- 都道府県(出品の地域表示に使用)
    bio           TEXT,
    avatar_path   TEXT,                      -- ローカルディスク上の相対パス
    role          TEXT NOT NULL DEFAULT 'user'
                  CHECK (role IN ('user', 'editor', 'moderator', 'admin')),
    is_suspended  BOOLEAN NOT NULL DEFAULT false,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- shared: 分類(ホーム画面のグリッドに対応)
-- ---------------------------------------------------------------------
CREATE TABLE shared.categories (
    id         SERIAL PRIMARY KEY,
    slug       TEXT NOT NULL UNIQUE,         -- 'fruit-veg', 'leaf-veg' 等
    name       TEXT NOT NULL,                -- 果菜 / 葉菜 / 根菜 / 豆類 /
                                             -- 穀類 / ハーブ / 花 / 苗
    icon       TEXT,                         -- Flutter側アイコン名
    sort_order INT NOT NULL DEFAULT 0
);

INSERT INTO shared.categories (slug, name, sort_order) VALUES
    ('fruit-veg',  '果菜',   1),
    ('leaf-veg',   '葉菜',   2),
    ('root-veg',   '根菜',   3),
    ('beans',      '豆類',   4),
    ('grains',     '穀類',   5),
    ('herbs',      'ハーブ', 6),
    ('flowers',    '花',     7),
    ('seedlings',  '苗',     8);

-- ---------------------------------------------------------------------
-- shared: 品目マスタ(作物。統合アプリ「種の森」の情報設計の軸。
--         辞典・交換・料理〔将来の recipe スキーマ〕を品目ごとに束ねる)
-- ---------------------------------------------------------------------
CREATE TABLE shared.crops (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT NOT NULL UNIQUE,      -- 品目名(例: ダイコン)
    kana          TEXT,
    category_id   INT NOT NULL REFERENCES shared.categories(id),
    scientific_name TEXT,
    summary       TEXT,                      -- 品目ハブ画面の冒頭説明
    photo_path    TEXT,
    sort_order    INT NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- shared: 品種マスタ(3アプリの中心。辞典記事・出品の両方が参照)
-- ---------------------------------------------------------------------
CREATE TABLE shared.varieties (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT NOT NULL,             -- 品種名(例: 三浦大根)
    kana          TEXT,                      -- 読み(検索・ソート用)
    aliases       TEXT[] NOT NULL DEFAULT '{}',  -- 別名・地方名
    category_id   INT NOT NULL REFERENCES shared.categories(id),
    crop_id       UUID REFERENCES shared.crops(id),
                                             -- 品目。品種承認時に運営が紐付ける
    crop_name     TEXT,                      -- 作物名の自由入力(未紐付け時の
                                             -- フォールバック表示用)
    scientific_name TEXT,
    origin_region TEXT,                      -- 来歴地域
    seed_type     TEXT NOT NULL DEFAULT 'unknown'
                  CHECK (seed_type IN ('fixed', 'native', 'unknown')),
                  -- fixed=固定種 / native=在来種
    -- 種苗法対応: 登録品種は出品をアプリ側でブロックする
    is_registered_variety BOOLEAN NOT NULL DEFAULT false,
    registration_note     TEXT,              -- 確認時のメモ(品種登録DBの照合結果等)
    registration_checked_at TIMESTAMPTZ,
    registration_checked_by TEXT REFERENCES shared.app_users(id),
    summary       TEXT,                      -- 一覧・サジェスト用の短い説明
    -- ユーザー提案の承認フロー(出品画面からの新規品種提案もここに入る)
    status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected')),
    proposed_by   TEXT REFERENCES shared.app_users(id),
    reviewed_by   TEXT REFERENCES shared.app_users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (name, crop_name)
);

CREATE INDEX idx_varieties_category ON shared.varieties (category_id)
    WHERE status = 'approved';
CREATE INDEX idx_varieties_crop ON shared.varieties (crop_id)
    WHERE status = 'approved';
CREATE INDEX idx_varieties_name_trgm ON shared.varieties
    USING gin (name gin_trgm_ops);           -- 要: CREATE EXTENSION pg_trgm;
                                             -- 出品時のインクリメンタル検索用

-- ---------------------------------------------------------------------
-- shared: 販売店(たねの森・野口のタネ等。販売店アプリの主体)
-- ---------------------------------------------------------------------
CREATE TABLE shared.shops (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug          TEXT NOT NULL UNIQUE,      -- 'tanenomori' 等。URL・表示に使用
    code          TEXT NOT NULL UNIQUE,      -- 店舗識別コード(例 'NOGUCHI')。
                                             -- 経理エクスポートの店舗列に使う
                                             -- (申込番号には含めない)
    name          TEXT NOT NULL,             -- 店名
    description   TEXT,
    website_url   TEXT,
    region        TEXT,
    logo_path     TEXT,
    contact_phone TEXT,                      -- 特商法表示の連絡先
    return_policy TEXT,                      -- 返品の可否と条件(特商法表示)
    delivery_time TEXT,                      -- 引き渡し時期(特商法表示)
    is_verified   BOOLEAN NOT NULL DEFAULT false,  -- 運営が確認した正規店。
                                             -- 出品に店舗バッジが付く
    is_active     BOOLEAN NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 店舗スタッフ(1店舗に複数ユーザーが所属できる)
CREATE TABLE shared.shop_members (
    shop_id   UUID NOT NULL REFERENCES shared.shops(id) ON DELETE CASCADE,
    user_id   TEXT NOT NULL REFERENCES shared.app_users(id),
    role      TEXT NOT NULL DEFAULT 'staff'
              CHECK (role IN ('owner', 'staff')),
    -- 担当部門/担当者名(自由入力。例「種苗部 田中」「通販担当」)。
    -- 認証は個人別なので、同一店舗に複数の担当者が各自のアカウントで
    -- 所属できる。申込み対応時に「誰が対応したか」の表示・記録に使う
    contact_label TEXT,
    PRIMARY KEY (shop_id, user_id)
);

CREATE TRIGGER trg_shops_touch BEFORE UPDATE ON shared.shops
    FOR EACH ROW EXECUTE FUNCTION shared.touch_updated_at();

-- =====================================================================
-- exchange: 種の交換アプリ
-- =====================================================================

CREATE TABLE exchange.listings (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       TEXT NOT NULL REFERENCES shared.app_users(id),
    -- 店舗出品の場合にセット。NULLなら個人出品。
    -- 店舗出品は一覧・詳細に店舗バッジと店名を表示する
    shop_id       UUID REFERENCES shared.shops(id),
    -- 品種マスタとの紐付け。未登録品種は variety_name_free に自由入力し、
    -- 同時に shared.varieties へ status='pending' の提案レコードを作る
    variety_id    UUID REFERENCES shared.varieties(id),
    variety_name_free TEXT,
    CHECK (variety_id IS NOT NULL OR variety_name_free IS NOT NULL),
    category_id   INT NOT NULL REFERENCES shared.categories(id),
    title         TEXT NOT NULL,
    description   TEXT NOT NULL DEFAULT '',
    item_kind     TEXT NOT NULL DEFAULT 'seed'
                  CHECK (item_kind IN ('seed', 'seedling', 'produce')),
                  -- 種 / 苗 / 生産物(生鮮野菜)。
                  -- 加工品・許可要食品は対象外(将来の別ドメイン)
    listing_type  TEXT NOT NULL
                  CHECK (listing_type IN ('exchange', 'sell', 'give')),
    price_yen     INT CHECK (price_yen IS NULL OR price_yen > 0),
                                             -- sell のときのみ。決済はアプリ外
    desired_trade TEXT,                      -- exchange のときの希望品
    quantity_note TEXT,                      -- 例: 「小袋約30粒」
    harvest_year  INT,                       -- 採種年
    is_self_saved BOOLEAN NOT NULL DEFAULT false,  -- 自家採種か
    region        TEXT,                      -- 栽培地域(気候の参考)
    cultivation_note TEXT,                   -- 栽培メモ(辞典への導線)
    -- 在庫: aiseed は在庫を持たない。在庫の正は店側にあり、
    -- 店側在庫API(標準HTTP+JSON)から取得して表示するのみ。
    -- テスト段階は正確な数を表示し、表示粒度(内数: あり/わずか/なし等)は
    -- 後日決定。個人出品は在庫概念なし(status のみ)。
    -- 在庫の厳密な一致は追わず、ずれは申込み時に当事者間で吸収する
    -- 受け渡し方法。direct=直接受け渡し(直売・手渡し・取り置き)/
    -- mail=郵送。郵送のとき食品表示・特商法表示の要否が生じる
    delivery_method TEXT NOT NULL DEFAULT 'mail'
                  CHECK (delivery_method IN ('direct', 'mail')),
    -- 支払いの既定。後払いを原則とする(買い手リスクが小さい)。
    -- 前払いも当事者協議で可。最終的な方法・金額はアプリ外で当事者が決める
    payment_default TEXT NOT NULL DEFAULT 'later'
                  CHECK (payment_default IN ('later', 'prepay', 'cod')),
                  -- later=後払い / prepay=前払い / cod=着払い
    -- 生産物の郵送(通販)時の食品表示。生鮮野菜のみ対象。
    -- item_kind='produce' かつ delivery_method='mail' で必須
    food_name     TEXT,                      -- 名称(例: だいこん)
    food_origin   TEXT,                      -- 原産地(生産地)
    food_producer TEXT,                      -- 生産者名
    food_harvest_date DATE,                  -- 収穫日
    food_storage  TEXT,                      -- 保存方法
    -- 特定商取引法の販売者表示(郵送で業として売る事業者)。
    -- requires_tokushoho=true のとき、店舗プロフィール(氏名・住所・連絡先)+
    -- 返品方針・引き渡し時期を束ねて「特定商取引法に基づく表示」として出す
    requires_tokushoho BOOLEAN NOT NULL DEFAULT false,
    -- 個人出品の性質表示(表示義務の回避目的ではない)。
    -- 家庭採種品は発芽・生育を保証しない旨をカードに明示し、
    -- 正規業者の指定種苗(発芽率あり)と一目で区別できるようにする。
    -- 個人出品(requires_seed_label=false)で既定 true。
    no_warranty   BOOLEAN NOT NULL DEFAULT true,
    -- 指定種苗の表示義務(種苗法22条)対応。
    -- 種苗業者(店舗、または反復継続的に販売する個人)は表示必須。
    -- requires_seed_label が true の出品は下記を NOT NULL 相当で検証する
    -- (種苗業者=業として販売する者。個人の家庭的な交換・少量譲渡は対象外)
    requires_seed_label BOOLEAN NOT NULL DEFAULT false,
                                             -- true: 指定種苗の表示義務あり
    label_seller_name    TEXT,               -- 表示者の氏名/名称(義務時必須)
    label_seller_address TEXT,               -- 表示者の住所(義務時必須)
    label_production_area TEXT,              -- 生産地(国内は都道府県名。義務時必須)
    label_germination_rate TEXT,             -- 発芽率(例: 2025年10月現在 80%以上)
                                             -- 種子のとき義務時必須(苗は不要)
    label_seed_treatment TEXT,               -- 種子消毒等の薬剤処理(あれば)
                                             -- 例: 「種子消毒あり(チウラム)」/「無処理」
    -- 種苗法対応: 出品者による「登録品種ではない」確認(UI必須チェック)
    non_registered_confirmed BOOLEAN NOT NULL,
    CHECK (non_registered_confirmed = true),
    status        TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'reserved', 'closed',
                                    'suspended')),
    moderation    TEXT NOT NULL DEFAULT 'approved'
                  CHECK (moderation IN ('approved', 'flagged', 'removed')),
                  -- 事後審査方式。通報や登録品種疑いで flagged に落とす
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_listings_home ON exchange.listings
    (category_id, created_at DESC)
    WHERE status = 'active' AND moderation = 'approved';
CREATE INDEX idx_listings_user ON exchange.listings (user_id);
CREATE INDEX idx_listings_shop ON exchange.listings (shop_id)
    WHERE shop_id IS NOT NULL;
CREATE INDEX idx_listings_variety ON exchange.listings (variety_id);

CREATE TABLE exchange.listing_photos (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES exchange.listings(id)
               ON DELETE CASCADE,
    path       TEXT NOT NULL,                -- ローカルディスク上の相対パス
    sort_order INT NOT NULL DEFAULT 0
);

CREATE INDEX idx_photos_listing ON exchange.listing_photos (listing_id);

-- ---------------------------------------------------------------------
-- exchange: カート(サーバー保持。端末をまたいで同期)
-- ---------------------------------------------------------------------
CREATE TABLE exchange.cart_items (
    user_id    TEXT NOT NULL REFERENCES shared.app_users(id),
    listing_id UUID NOT NULL REFERENCES exchange.listings(id)
               ON DELETE CASCADE,
    quantity   INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    added_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, listing_id)
);

-- ---------------------------------------------------------------------
-- exchange: 申込み(カートから提供者ごとに送る。取引の単位)
--   提供者 = 出品の shop_id があれば店舗、なければ個人
-- ---------------------------------------------------------------------
CREATE TABLE exchange.requests (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id      TEXT NOT NULL REFERENCES shared.app_users(id),
    provider_user_id  TEXT REFERENCES shared.app_users(id),   -- 個人提供者
    provider_shop_id  UUID REFERENCES shared.shops(id),       -- 店舗提供者
    CHECK ((provider_user_id IS NULL) <> (provider_shop_id IS NULL)),
    -- 申込番号(経理・外部販売システムとの照合キー)。
    -- このデータベース全体で一連の通し番号(店舗・個人を区別しない)。
    -- 形式: 年 + '-' + 5桁連番(例: 2026-00042)。
    -- 一意性は request_no 単独で担保する。将来 店のDBを分離したら、
    -- その新DBの中で改めて一連の番号になる(採番単位=データベース)。
    -- 店舗の識別は経理エクスポートの店舗列で行う(番号には含めない)。
    -- 全ての申込み(店舗宛・個人間とも)に採番する
    request_no  TEXT UNIQUE NOT NULL,           -- 挿入時にアプリが採番して渡す
                                                -- (既定値なし。空文字での挿入禁止:
                                                --  UNIQUE衝突を防ぐ)
    request_year INT,                           -- 採番した年(連番の区切り)
    request_seq  INT,                            -- その年の通し連番
    status     TEXT NOT NULL DEFAULT 'requested'
               CHECK (status IN ('requested',   -- 申込み中
                                 'accepted',    -- 提供者が承諾(取引進行)
                                 'declined',    -- 提供者が辞退
                                 'completed',   -- 双方確認で完了 → 評価へ
                                 'cancelled',   -- 申込者が取下げ
                                 'expired')),   -- 放置で自動クローズ(定期ジョブ)
    note        TEXT,                           -- 申込み時の一言
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),  -- 申込み(受付)日時
    accepted_at TIMESTAMPTZ,                    -- 店が承諾した日時
    accepted_by TEXT REFERENCES shared.app_users(id),  -- 承諾した担当者
                                                -- (店舗宛の申込みのみ。経理・
                                                --  問い合わせ追跡用)
    completed_at TIMESTAMPTZ,                   -- 成約(完了)日時。売上計上の基準
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_requests_requester ON exchange.requests
    (requester_id, created_at DESC);
CREATE INDEX idx_requests_provider_user ON exchange.requests
    (provider_user_id) WHERE provider_user_id IS NOT NULL;
CREATE INDEX idx_requests_provider_shop ON exchange.requests
    (provider_shop_id) WHERE provider_shop_id IS NOT NULL;

CREATE TABLE exchange.request_items (
    request_id UUID NOT NULL REFERENCES exchange.requests(id)
               ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES exchange.listings(id),
    quantity   INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (request_id, listing_id)
);

-- ---------------------------------------------------------------------
-- exchange: メッセージ(申込み単位のスレッド)
-- ---------------------------------------------------------------------
CREATE TABLE exchange.messages (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES exchange.requests(id)
               ON DELETE CASCADE,
    sender_id  TEXT NOT NULL REFERENCES shared.app_users(id),
    body       TEXT NOT NULL,
    sent_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at    TIMESTAMPTZ                   -- 未読管理+メール通知の抑制判定
);

CREATE INDEX idx_messages_request ON exchange.messages (request_id, sent_at);

-- ---------------------------------------------------------------------
-- exchange: 取引後の相互評価(申込み単位)
-- ---------------------------------------------------------------------
CREATE TABLE exchange.reviews (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id  UUID NOT NULL REFERENCES exchange.requests(id),
    reviewer_id TEXT NOT NULL REFERENCES shared.app_users(id),
    reviewee_id TEXT NOT NULL REFERENCES shared.app_users(id),
    score       INT NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (request_id, reviewer_id)         -- 1申込みにつき各1回
);

CREATE INDEX idx_reviews_reviewee ON exchange.reviews (reviewee_id);

-- ---------------------------------------------------------------------
-- exchange: 通報(出品・メッセージ・ユーザー共通)
-- ---------------------------------------------------------------------
CREATE TABLE exchange.reports (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id TEXT NOT NULL REFERENCES shared.app_users(id),
    target_type TEXT NOT NULL
                CHECK (target_type IN ('listing', 'message', 'user',
                                       'variety', 'revision', 'request')),
    target_id   TEXT NOT NULL,               -- 対象のID(型混在のためTEXT)
    reason      TEXT NOT NULL,               -- 'registered_variety'(登録品種疑い)
                                             -- 'spam' / 'fraud' / 'other'
    detail      TEXT,
    status      TEXT NOT NULL DEFAULT 'open'
                CHECK (status IN ('open', 'resolved', 'dismissed')),
    handled_by  TEXT REFERENCES shared.app_users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_reports_open ON exchange.reports (created_at)
    WHERE status = 'open';

-- =====================================================================
-- dictionary: 伝統野菜辞典(リビジョン制・承認フロー付き)
-- =====================================================================

-- 記事は品種と1:1。品種がマスタ承認されたらAPI側で記事枠を自動作成する
CREATE TABLE dictionary.articles (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variety_id          UUID NOT NULL UNIQUE
                        REFERENCES shared.varieties(id),
    current_revision_id UUID,                -- 公開中リビジョン(承認時に更新)
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dictionary.revisions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id   UUID NOT NULL REFERENCES dictionary.articles(id)
                 ON DELETE CASCADE,
    author_id    TEXT NOT NULL REFERENCES shared.app_users(id),
    -- 本文はセクション構造のJSONB。Flutter側はセクション単位で編集UIを出す
    -- {"history": "...", "cultivation": "...", "seed_saving": "...",
    --  "cooking": "...", "sources": "..."}
    content      JSONB NOT NULL,
    edit_summary TEXT,                       -- 変更内容の一言(履歴表示用)
    status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by  TEXT REFERENCES shared.app_users(id),
    review_note  TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_revisions_queue ON dictionary.revisions (created_at)
    WHERE status = 'pending';                -- 管理画面の承認キュー用
CREATE INDEX idx_revisions_article ON dictionary.revisions
    (article_id, created_at DESC);

ALTER TABLE dictionary.articles
    ADD CONSTRAINT fk_current_revision
    FOREIGN KEY (current_revision_id) REFERENCES dictionary.revisions(id);

-- ---------------------------------------------------------------------
-- dictionary: 記事写真(品種の姿・栽培風景。出品写真とは別管理)
-- ---------------------------------------------------------------------
CREATE TABLE dictionary.article_photos (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id  UUID NOT NULL REFERENCES dictionary.articles(id)
                ON DELETE CASCADE,
    uploaded_by TEXT NOT NULL REFERENCES shared.app_users(id),
    path        TEXT NOT NULL,
    caption     TEXT,
    status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'approved', 'rejected')),
    sort_order  INT NOT NULL DEFAULT 0
);

-- =====================================================================
-- 共通: updated_at 自動更新トリガ(関数はファイル冒頭で定義済み)
-- =====================================================================
CREATE TRIGGER trg_users_touch BEFORE UPDATE ON shared.app_users
    FOR EACH ROW EXECUTE FUNCTION shared.touch_updated_at();
CREATE TRIGGER trg_crops_touch BEFORE UPDATE ON shared.crops
    FOR EACH ROW EXECUTE FUNCTION shared.touch_updated_at();
CREATE TRIGGER trg_varieties_touch BEFORE UPDATE ON shared.varieties
    FOR EACH ROW EXECUTE FUNCTION shared.touch_updated_at();
CREATE TRIGGER trg_listings_touch BEFORE UPDATE ON exchange.listings
    FOR EACH ROW EXECUTE FUNCTION shared.touch_updated_at();
CREATE TRIGGER trg_requests_touch BEFORE UPDATE ON exchange.requests
    FOR EACH ROW EXECUTE FUNCTION shared.touch_updated_at();

-- 必要な拡張(スーパーユーザーで一度だけ)
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
