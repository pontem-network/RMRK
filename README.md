# Initial NFT implementation (RMRK) in Move language

* [RMRK Website](https://www.rmrk.app/)
* [RMRK Standard](https://github.com/rmrk-team/rmrk-spec/tree/master/standards/rmrk2.0.0)

Entities:

* NFT
* Collection

Interactions:

* CREATE (COLLECTION)
* CHANGEISSUER (COLLECTION)
* LOCK (COLLECTION)

* MINT (NFT)
* TRANSFER (NFT)
* BURN (NFT)

# How to build

Install
move-cli https://github.com/diem/diem/tree/main/language/tools/move-cli
to get `move` binary.

To build package:

```shell
git clone https://github.com/pontem-network/RMRK.git
cd RMRK
move package build
```

To run tests:

```shell
move package test
```
