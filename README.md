# Initial NFT implementation (RMRK) in Move language

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
move-cli [https://github.com/diem/diem/tree/main/language/tools/move-cli](https://github.com/diem/diem/tree/main/language/tools/move-cli)
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
