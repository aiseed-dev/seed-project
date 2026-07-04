// SPDX-License-Identifier: AGPL-3.0-only
/// 接続先。ビルド時に --dart-define で上書きできる。
const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8000/api/v1',
);
const pbBase = String.fromEnvironment(
  'PB_BASE',
  defaultValue: 'http://localhost:8090',
);

/// レスポンシブ境界(docs/05)。これ以上はワイド(左ナビ・表形式)。
const wideBreakpoint = 900.0;
