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
