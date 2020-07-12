# oci-modify-cluster-hostname
## 概要
OCI(Oracle Cloud Infrastructure) にて HPC 用途のクラスターを構築した際、インスタンス名やホスト名がランダムに生成される。
それを任意のインスタンス名、ホスト名に変更するスクリプトです。

## 前提
### 実行するノード
bastion ノードから実行してください。
### OCI CLI
oci cli が bastion ノードにインストールされていること。
```
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

oci setup config を実行し設定が完了していること
```
oci setup config
```


