# oci-modify-cluster-hostname
## 概要
OCI(Oracle Cloud Infrastructure) にて HPC 用途のクラスターを構築した際、インスタンス名やホスト名がランダムに生成される。
それを任意のインスタンス名、ホスト名に変更するスクリプトです。

すでに利用中のクラスターに対する実行はおすすめしません。クラスターの作成後に実施し、十分に確認を行った上でご利用ください。

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


## このスクリプトによる変更される点
### bastion
- /etc/ansible/hosts
### BM.HPC2.36
- インスタンスの display-name
- インスタンスの VNIC の display-name
- インスタンスの VNIC の --hostname-label (FQDN)
- /etc/hosts
- hostname
- /etc/opt/oci-hpc/hostfile.rdma
- /etc/opt/oci-hpc/hostfile.tcp

## 実行方法 

## 注意事項
### Resource Manager から Destroy できなくなる
インスタンス名が変わったのが影響していると思われる。手動で以下を行ってください。
- Cluster Network を TERMINATE
- Bastion の TERMINATE
- 必要であれば VCN の削除
