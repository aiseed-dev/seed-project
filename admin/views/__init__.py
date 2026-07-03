# SPDX-License-Identifier: MIT
# 先に boot を import して backend(models/services)を sys.path に載せる。
# 各 view の import より必ず先に実行される(パッケージ初期化)。
import boot  # noqa: F401
