**NOTICE Jan 10 2018:** The atomic swap contract has been updated to use SHA256
 secret hashes (instead of RIPEMD160) as it is more secure and has wider
 compatibility with altcoins.  Old contracts will not be usable by the new tools
 and vice-versa.  Please rebuild all tools before conducting new atomic swaps.

# Litecoin cross-chain atomic swapping

This repo contains utilities to manually perform cross-chain atomic swaps
between Litecoin and other cryptocurrencies.  At the moment,Decred (Decred Core) Viacoin (Viacoin
Core), Litecoin (Litecoin Core), Vertcoin (Vertcoin Core) and Particl (Particl Core) are the four
other blockchains and wallets supported.  Support for other blockchains or 
wallets could be added in the future.

These tools do not operate solely on-chain.  A side-channel is required between
each party performing the swap in order to exchange additional data.  This
side-channel could be as simple as a text chat and copying data.  Until a more
streamlined implementation of the side channel exists, such as the Lightning
Network, these tools suffice as a proof-of-concept for cross-chain atomic swaps
and a way for early adopters to try out the technology.

Due to the requirements of manually exchanging data and creating, sending, and
watching for the relevant transactions, it is highly recommended to read this
README in its entirety before attempting to use these tools.  The sections 
below explain the principles on which the tools operate, the instructions for 
how to use them safely, and an example swap between Litecoin and Viacoin.

## Build instructions

Pre-requirements:

  - Go 1.9 or later
  - [dep](https://github.com/golang/dep)
  - `viacoin` 0.13 or later (for `viaatomicswap`)

```
$ cd $GOPATH/src/github.com/viacoin
$ git clone https://github.com/viacoin/atomicswap && cd atomicswap
$ dep ensure
$ go install ./cmd/...
```

## Theory

A cross-chain swap is a trade between two users of different cryptocurrencies.
For example, one party may send Litecoin to a second party's Litecoin address, while
the second party would send Viacoin to the first party's Viacoin address.
However, as the blockchains are unrelated and transactions can not be reversed,
this provides no protection against one of the parties never honoring their end
of the trade.  One common solution to this problem is to introduce a
mutually-trusted third party for escrow.  An atomic cross-chain swap solves this
problem without the need for a third party.

Atomic swaps involve each party paying into a contract transaction, one contract
for each blockchain.  The contracts contain an output that is spendable by
either party, but the rules required for redemption are different for each party
involved.

One party (called counterparty 1 or the initiator) generates a secret and pays
the intended trade amount into a contract transaction.  The contract output can
be redeemed by the second party (called countryparty 2 or the participant) as
long as the secret is known.  If a period of time (typically 48 hours) expires
after the contract transaction has been mined but has not been redeemed by the
participant, the contract output can be refunded back to the initiator's wallet.

For simplicity, we assume the initiator wishes to trade Viacoin for Litecoin with
the participant.  The initiator can also trade Litecoin for Viacoin and the steps
will be the same, but with each step performed on the other blockchain.

The participant is unable to spend from the initiator's Viacoin contract at this
point because the secret is unknown by them.  If the initiator revealed their
secret at this point, the participant could spend from the contract without ever
honoring their end of the trade.

The participant creates a similar contract transaction to the initiator's but on
the Litecoin blockchain and pays the intended Litecoin amount into the contract.
However, for the initiator to redeem the output, their own secret must be
revealed.  For the participant to create their contract, the initiator must
reveal not the secret, but a cryptographic hash of the secret to the
participant.  The participant's contract can also be refunded by the
participant, but only after half the period of time that the initiator is
required to wait before their contract can be refunded (typically 24 hours).

With each side paying into a contract on each blockchain, and each party unable
to perform their refund until the allotted time expires, the initiator redeems
the participant's Litecoin contract, thereby revealing the secret to the
participant.  The secret is then extracted from the initiator's redeeming Litecoin
transaction providing the participant with the ability to redeem the initiator's
Viacoin contract.

This procedure is atomic (with timeout) as it gives each party at least 24 hours
to redeem their coins on the other blockchain before a refund can be performed.

The image below provides a visual of the steps each party performs and the
transfer of data between each party.

<img src="workflow.svg" width="100%" height=650 />

## Command line

Separate command line utilities are provided to handle the transactions required
to perform a cross-chain atomic swap for each supported blockchain.  For a swap
between Viacoin and Litecoin, the two utilities `viacatomicswap` and
`ltcatomicswap` are used.  Both tools must be used by both parties performing
the swap.

Different tools may require different flags to use them with the supported
wallet.  For example, `viaatomicswap` includes flags for the RPC username and
password same as for `ltcatomicswap`.  Running a tool without any parameters
will show the full usage help.

All of the tools support the same six commands.  These commands are:

```
Commands:
  initiate <participant address> <amount>
  participate <initiator address> <amount> <secret hash>
  redeem <contract> <contract transaction> <secret>
  refund <contract> <contract transaction>
  extractsecret <redemption transaction> <secret hash>
  auditcontract <contract> <contract transaction>
```

**`initiate <participant address> <amount>`**

The `initiate` command is performed by the initiator to create the first
contract.  The contract is created with a locktime of 48 hours in the future.
This command returns the secret, the secret hash, the contract script, the
contract transaction, and a refund transaction that can be sent after 48 hours
if necessary.

Running this command will prompt for whether to publish the contract
transaction.  If everything looks correct, the transaction should be published.
The refund transaction should be saved in case a refund is required to be made
later.

For dcratomicswap, this step prompts for the wallet passphrase.  For the
viaatomicswap and ltcatomicswap tools the wallet must already be unlocked.

**`participate <initiator address> <amount> <secret hash>`**

The `participate` command is performed by the participant to create a contract
on the second blockchain.  It operates similarly to `initiate` but requires
using the secret hash from the initiator's contract and creates the contract
with a locktime of 24 hours.

Running this command will prompt for whether to publish the contract
transaction.  If everything looks correct, the transaction should be published.
The refund transaction should be saved in case a refund is required to be made
later.

For dcratomicswap, this step prompts for the wallet passphrase.  For the
viaatomicswap and ltcatomicswap tools the wallet must already be unlocked.

**`redeem <contract> <contract transaction> <secret>`**

The `redeem` command is performed by both parties to redeem coins paid into the
contract created by the other party.  Redeeming requires the secret and must be
performed by the initiator first.  Once the initiator's redemption has been
published, the secret may be extracted from the transaction and the participant
may also redeem their coins.

Running this command will prompt for whether to publish the redemption
transaction. If everything looks correct, the transaction should be published.

For dcratomicswap, this step prompts for the wallet passphrase.  For the
viaatomicswap and ltcatomicswap tools the wallet must already be unlocked.

**`refund <contract> <contract transaction>`**

The `refund` command is used to create and send a refund of a contract
transaction.  While the refund transaction is created and displayed during
contract creation in the initiate and participate steps, the refund can also be
created after the fact in case there was any issue sending the transaction (e.g.
the contract transaction was malleated or the refund fee is now too low).

Running this command will prompt for whether to publish the redemption
transaction. If everything looks correct, the transaction should be published.

**`extractsecret <redemption transaction> <secret hash>`**

The `extractsecret` command is used by the participant to extract the secret
from the initiator's redemption transaction.  With the secret known, the
participant may claim the coins paid into the initiator's contract.

The secret hash is a required parameter so that "nonstandard" redemption
transactions won't confuse the tool and the secret can still be discovered.

**`auditcontract <contract> <contract transaction>`**

The `auditcontract` command inspects a contract script and parses out the
addresses that may claim the output, the locktime, and the secret hash.  It also
validates that the contract transaction pays to the contract and reports the
contract output amount.  Each party should audit the contract provided by the
other to verify that their address is the recipient address, the output value is
correct, and that the locktime is sensible.

## Example

The first step is for both parties to exchange addresses on both blockchains. If
party A (the initiator) wishes to trade Viacoin for Litecoin, party B (the
participant) must provide their Viacoin address and the initiator must provide
the participant their Litecoin address.

_Alice runs:_
```
$ litecoin-cli -testnet getnewaddress
mo8T4iqg6mCAxAtZocwocisBnnCj1SjtD7
```

_Bob runs:_
```
$ viacoin-cli -testnet getnewaddress
tCzCYhhas9bxx5a3hNTCT6g7gmoASnkYFc
```

*Note:* It is normal for neither of these addresses to show any activity on
block explorers.  They are only used in nonstandard scripts that the block
explorers do not recognize.

Alice initiates the process by using `viaatomicswap` to pay 1.0 VIA into the Viacoin
contract using Bob's Viacoin address, sending the contract transaction, and
sharing the secret hash (*not* the secret), contract, and contract transaction
with Bob.  The refund transaction can not be sent until the locktime expires, but
should be saved in case a refund is necessary.

_Alice runs:_
```
$ viaatomicswap --testnet --rpcuser=viarpc --rpcpass=viapass initiate tCzCYhhas9bxx5a3hNTCT6g7gmoASnkYFc 1.0
warning: falling back to mempool relay fee policy
Secret:      b62b3b1c27ada27ae9939cb3885b29aa5a0ca3031b2b81fc3730ae6f36e2a74c
Secret hash: 753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b04

Contract fee: 0.000224 VIA (0.00100000 VIA/kB)
Refund fee:   0.000293 VIA (0.00101736 VIA/kB)

Contract (2N3WGX7fxYnsaQ7ATgt2Nzxc964A2VeCSZa):
63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914427eccead89fd187b4b80e414c94a9cbd798bf1667046c795b5ab17576a914414e19736e7c718cdb532ad5e6f045a4d6c47b5a6888ac

Contract transaction (9d668fc6f4dfe2dca2af980e6525352d49f62682c2b8a35176b3a7fef76e0d33):
02000000013328bf00e003539fafcaca5fa069280456ceb2ffe63a074963b8db6e85b37fef000000006b4830450221008bb37d82362c23f5f097d37e03268b1cca83f8bc445d4639e426901a6175a1c802203ce6ccc6b88d5cd999987455248e671e708f2b03afa2b8320e204fbec75bce8f0121021bdf64267e7ad297726aa529cf7e61cf8ceb67acbbc9c57ae4df546680788274feffffff0280677c48180900001976a91443306976fdfa61c447055cdb1aea3fe9a3eb3ebd88ac00e1f5050000000017a91470899c4b5ad673c87a8e0b5faf68b092c0c79a818700000000

Refund transaction (00672eb4cf97ae21ab7a9e196310b10b9abf0bdd2ae22d42843bc6a0df931355):
0200000001330d6ef7fea7b37651a3b8c28226f6492d3525650e98afa2dce2dff4c68f669d01000000cb48304502210089212e0299baedcc3bc6e9e3ef707d50a84a9b1676e0d272a90b8906581e1db5022014ba8ae371946bdee8535fabe9a1fde201a4ab52b6613fedaeafb24958a24e330121020da7c60c0950ebb00cd7ea8223ac6b38ff61f418ddc7f775f38e76837076d51e004c5d63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914427eccead89fd187b4b80e414c94a9cbd798bf1667046c795b5ab17576a914414e19736e7c718cdb532ad5e6f045a4d6c47b5a6888ac00000000018c6ef505000000001976a91443306976fdfa61c447055cdb1aea3fe9a3eb3ebd88ac6c795b5a

Publish contract transaction? [y/N] y
Published contract transaction (9d668fc6f4dfe2dca2af980e6525352d49f62682c2b8a35176b3a7fef76e0d33)
```

Once Alice has initialized the swap, Bob must audit the contract and contract
transaction to verify: 

1. The recipient address was the VIA address that was provided to Alice
2. The contract value is the expected amount of VIA to receive
3. The locktime was set to 48 hours in the future

_Bob runs:_
```
$ viaatomicswap --testnet --rpcuser=viarpc --rpcpass=viapass auditcontract 63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914427eccead89fd187b4b80e414c94a9cbd798bf1667046c795b5ab17576a914414e19736e7c718cdb532ad5e6f045a4d6c47b5a6888ac 02000000013328bf00e003539fafcaca5fa069280456ceb2ffe63a074963b8db6e85b37fef000000006b4830450221008bb37d82362c23f5f097d37e03268b1cca83f8bc445d4639e426901a6175a1c802203ce6ccc6b88d5cd999987455248e671e708f2b03afa2b8320e204fbec75bce8f0121021bdf64267e7ad297726aa529cf7e61cf8ceb67acbbc9c57ae4df546680788274feffffff0280677c48180900001976a91443306976fdfa61c447055cdb1aea3fe9a3eb3ebd88ac00e1f5050000000017a91470899c4b5ad673c87a8e0b5faf68b092c0c79a818700000000
Contract address:        2N3WGX7fxYnsaQ7ATgt2Nzxc964A2VeCSZa
Contract value:          1 VIA
Recipient address:       tCzCYhhas9bxx5a3hNTCT6g7gmoASnkYFc
Author's refund address: tCsuXhjMpF5Sz8j1rnr1A2ybm2KKEovQ4e

Secret hash: 753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b04

Locktime: 2018-01-14 15:38:20 +0000 UTC
Locktime reached in 47h55m4s
```

Auditing the contract also reveals the hash of the secret, which is needed for
the next step.

Once Bob trusts the contract, they may participate in the cross-chain atomic swap
by paying the intended Litecoin amount (0.1 in this example) into a Litecoin
contract using the same secret hash.  The contract transaction may be published
at this point.  The refund transaction can not be sent until the locktime
expires, but should be saved in case a refund is necessary.

_Bob runs:_
```
$ ltcatomicswap --testnet --rpcuser=literpc --rpcpass=litepass participate mo8T4iqg6mCAxAtZocwocisBnnCj1SjtD7 0.1 753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b04
Contract fee: 0.00046482 LTC (0.00208439 LTC/kB)
Refund fee:   0.00060801 LTC (0.00211115 LTC/kB)

Contract (2N6bnC8JPrdyuDukgvHdt2qQf8Uph6x1T2L):
63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914537f748b77747bb63e6c54dc72cb964b88d154486704012a5a5ab17576a91416877ea36c0fc5653fcb3d0f1c423c633c95f01e6888ac

Contract transaction (95929b639cc729a1a89b3fa72e6f2de589e53c4336d52e24c982ec11ccc0529a):
0200000001341d2139c84baca7e3ee772e43342bb5adae29ac97f7bf825d1e631ccbbdfdd8000000006a4730440220077a466948ba9b1bcd3810de53eb365a07007b444a253a9a96631ca6ea120fd6022050af903896ae33403e2c92d337bbd5f79789a526245d3a2aa033f1a060f15662012103bd3db3ee6866fa8a340128f9b38a4990786f82c3189c8c16bd828ac1b141c161feffffff02ed63f702000000001976a91441f956d3257b7b8689a51d1938599ba88e2b718788ac809698000000000017a914927cd64dcd1c89bb9a26860e7d6f49ee07f217158700000000

Refund transaction (6bec919ef5bdd3ade5bed5f7444625f13a0b8b2013ce300fe9effc242139716f):
02000000019a52c0cc11ec82c9242ed536433ce589e52d6f2ea73f9ba8a129c79c639b929501000000cb48304502210099fa0e782c7b605789a8fc0f1717a0ae2216c17834b144e571dee23a1c399db0022076deb568476ae0bf1fccbd268459cf52f0e990ddc5ab55eacecd4275e82bc811012103854514be427b60622ec714c707fa6dc5b432bd457d0763d5b5495fd92175077e004c5d63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914537f748b77747bb63e6c54dc72cb964b88d154486704012a5a5ab17576a91416877ea36c0fc5653fcb3d0f1c423c633c95f01e6888ac0000000001ffa89700000000001976a914e37f21a2edfaa0a5917618928b16776cf6c22ae288ac012a5a5a

Publish contract transaction? [y/N] y
Published contract transaction (95929b639cc729a1a89b3fa72e6f2de589e53c4336d52e24c982ec11ccc0529a)

```

Bob now informs Alice that the Litecoin contract transaction has been created and
published, and provides the contract details to Alice.

Just as Bob needed to audit Alice's contract before locking their coins in a contract,
Alice must do the same with Bob's contract before withdrawing from the contract.  Alice
audits the contract and contract transaction to verify:

1. The recipient address was the LTC address that was provided to Bob
2. The contract value is the expected amount of LTC to receive
3. The locktime was set to 24 hours in the future
4. The secret hash matches the value previously known

_Alice runs:_
```
$ ltcatomicswap --testnet --rpcuser=literpc --rpcpass=litepass auditcontract 63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914537f748b77747bb63e6c54dc72cb964b88d154486704012a5a5ab17576a91416877ea36c0fc5653fcb3d0f1c423c633c95f01e6888ac 0200000001341d2139c84baca7e3ee772e43342bb5adae29ac97f7bf825d1e631ccbbdfdd8000000006a4730440220077a466948ba9b1bcd3810de53eb365a07007b444a253a9a96631ca6ea120fd6022050af903896ae33403e2c92d337bbd5f79789a526245d3a2aa033f1a060f15662012103bd3db3ee6866fa8a340128f9b38a4990786f82c3189c8c16bd828ac1b141c161feffffff02ed63f702000000001976a91441f956d3257b7b8689a51d1938599ba88e2b718788ac809698000000000017a914927cd64dcd1c89bb9a26860e7d6f49ee07f217158700000000
Contract address:        2N6bnC8JPrdyuDukgvHdt2qQf8Uph6x1T2L
Contract value:          0.1 LTC
Recipient address:       mo8T4iqg6mCAxAtZocwocisBnnCj1SjtD7
Author's refund address: mha5UcKYtC7pi6tpk4dA6YD411E67ARxWx

Secret hash: 753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b04

Locktime: 2018-01-13 15:47:13 +0000 UTC
Locktime reached in 23h56m23s
```

Now that both parties have paid into their respective contracts, Alice may withdraw
from the Litecoin contract.  This step involves publishing a transaction which
reveals the secret to Bob, allowing Bob to withdraw from the Viacoin contract.

_Alice runs:_
```
$ ltcatomicswap --testnet --rpcuser=literpc --rpcpass=litepass redeem 63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914537f748b77747bb63e6c54dc72cb964b88d154486704012a5a5ab17576a91416877ea36c0fc5653fcb3d0f1c423c633c95f01e6888ac 0200000001341d2139c84baca7e3ee772e43342bb5adae29ac97f7bf825d1e631ccbbdfdd8000000006a4730440220077a466948ba9b1bcd3810de53eb365a07007b444a253a9a96631ca6ea120fd6022050af903896ae33403e2c92d337bbd5f79789a526245d3a2aa033f1a060f15662012103bd3db3ee6866fa8a340128f9b38a4990786f82c3189c8c16bd828ac1b141c161feffffff02ed63f702000000001976a91441f956d3257b7b8689a51d1938599ba88e2b718788ac809698000000000017a914927cd64dcd1c89bb9a26860e7d6f49ee07f217158700000000 b62b3b1c27ada27ae9939cb3885b29aa5a0ca3031b2b81fc3730ae6f36e2a74c
Redeem fee: 0.00067627 LTC (0.00210676 LTC/kB)

Redeem transaction (d4f28f0c53db2c034b03833069032f2b0cf9f98808b0b4d726ef35e0f26b4ec4):
02000000019a52c0cc11ec82c9242ed536433ce589e52d6f2ea73f9ba8a129c79c639b929501000000ec483045022100862ed6c63dfdaa4c4d448f7eb46e06e42c7dd211c34378c25c70ac4c777af7bd02200b643f017a2d1b2a132f43312650bb4733d3ecfb0d01cf89829135bed626d864012102a47ce2377f8ce9ca70fa0a1ef84a5ab3c03eac0ebcc180c7adf6b674abc656b020b62b3b1c27ada27ae9939cb3885b29aa5a0ca3031b2b81fc3730ae6f36e2a74c514c5d63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914537f748b77747bb63e6c54dc72cb964b88d154486704012a5a5ab17576a91416877ea36c0fc5653fcb3d0f1c423c633c95f01e6888acffffffff01558e9700000000001976a9142e1aa357602b0dac3e177c3cb04f5b0ac452796288ac012a5a5a

Publish redeem transaction? [y/N] y
Published redeem transaction (d4f28f0c53db2c034b03833069032f2b0cf9f98808b0b4d726ef35e0f26b4ec4)
```

Now that Alice has withdrawn from the Litecoin contract and revealed the secret, Bob
must extract the secret from this redemption transaction.  Bob may watch a block
explorer to see when the Litecoin contract output was spent and look up the
redeeming transaction.

_Bob runs:_
```
$ ltcatomicswap --testnet --rpcuser=literpc --rpcpass=litepass extractsecret 02000000019a52c0cc11ec82c9242ed536433ce589e52d6f2ea73f9ba8a129c79c639b929501000000ec483045022100862ed6c63dfdaa4c4d448f7eb46e06e42c7dd211c34378c25c70ac4c777af7bd02200b643f017a2d1b2a132f43312650bb4733d3ecfb0d01cf89829135bed626d864012102a47ce2377f8ce9ca70fa0a1ef84a5ab3c03eac0ebcc180c7adf6b674abc656b020b62b3b1c27ada27ae9939cb3885b29aa5a0ca3031b2b81fc3730ae6f36e2a74c514c5d63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914537f748b77747bb63e6c54dc72cb964b88d154486704012a5a5ab17576a91416877ea36c0fc5653fcb3d0f1c423c633c95f01e6888acffffffff01558e9700000000001976a9142e1aa357602b0dac3e177c3cb04f5b0ac452796288ac012a5a5a 753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b04
Secret: b62b3b1c27ada27ae9939cb3885b29aa5a0ca3031b2b81fc3730ae6f36e2a74c

```

With the secret known, Bob may redeem from Alice's Viacoin contract.

_Bob runs:_
```
$ viaatomicswap --testnet --rpcuser=viarpc --rpcpass=viapass redeem 63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914427eccead89fd187b4b80e414c94a9cbd798bf1667046c795b5ab17576a914414e19736e7c718cdb532ad5e6f045a4d6c47b5a6888ac 02000000013328bf00e003539fafcaca5fa069280456ceb2ffe63a074963b8db6e85b37fef000000006b4830450221008bb37d82362c23f5f097d37e03268b1cca83f8bc445d4639e426901a6175a1c802203ce6ccc6b88d5cd999987455248e671e708f2b03afa2b8320e204fbec75bce8f0121021bdf64267e7ad297726aa529cf7e61cf8ceb67acbbc9c57ae4df546680788274feffffff0280677c48180900001976a91443306976fdfa61c447055cdb1aea3fe9a3eb3ebd88ac00e1f5050000000017a91470899c4b5ad673c87a8e0b5faf68b092c0c79a818700000000 b62b3b1c27ada27ae9939cb3885b29aa5a0ca3031b2b81fc3730ae6f36e2a74c
warning: falling back to mempool relay fee policy
Redeem fee: 0.000326 BTC (0.00101875 VIA/kB)

Redeem transaction (fecb2de3d6fd9006a3124f1b7fa723d401ff421c0bae0c081158639994b6c8cd):
0200000001330d6ef7fea7b37651a3b8c28226f6492d3525650e98afa2dce2dff4c68f669d01000000eb47304402203d18ffad8f72b0506df8270924ab90e76bc984d860a82824e5988a11e39216ff02204caedaf92a948734914aeb6975544b28314de36a29fc26d4d9e594f216ee3901012102d70487eddedf7dd6bbd14bf3ac938ac45714fe0408f3c5a50ec9759d4d5f2bd420b62b3b1c27ada27ae9939cb3885b29aa5a0ca3031b2b81fc3730ae6f36e2a74c514c5d63a820753a983643fcd03293336b0d476adffd0a5a26d38b7e172cabe2b6c127ff2b048876a914427eccead89fd187b4b80e414c94a9cbd798bf1667046c795b5ab17576a914414e19736e7c718cdb532ad5e6f045a4d6c47b5a6888acffffffff01a861f505000000001976a914f2945cf18bf058003eb659f75bbc2eae1d287bb088ac6c795b5a

Publish redeem transaction? [y/N] y
Published redeem transaction (fecb2de3d6fd9006a3124f1b7fa723d401ff421c0bae0c081158639994b6c8cd)
```

The cross-chain atomic swap is now completed and successful.  This example was
performed on the public Viacoin and Litecoin testnet blockchains.  For reference,
here are the four transactions involved:

| Description | Transaction |
| - | - |
| Viacoin contract created by A | [9d668fc6f4dfe2dca2af980e6525352d49f62682c2b8a35176b3a7fef76e0d33] |
| Litecoin contract created by B | [95929b639cc729a1a89b3fa72e6f2de589e53c4336d52e24c982ec11ccc0529a] |
| A's Litecoin redemption | [fecb2de3d6fd9006a3124f1b7fa723d401ff421c0bae0c081158639994b6c8cd] |
| B's Viacoin redemption | [c49e6fd0057b601dbb8856ad7b3fcb45df626696772f6901482b08df0333e5a0] |

If at any point either party attempts to fraud (e.g. creating an invalid
contract, not revealing the secret and refunding, etc.) both parties have the
ability to issue the refund transaction created in the initiate/participate step
and refund the contract.

## Discovering raw transactions

Several steps require working with a raw transaction published by the other
party.  While the transactions can sometimes be looked up from a local node
using the `getrawtransaction` JSON-RPC, this method can be unreliable since the
set of queryable transactions depends on the current UTXO set (bitcoind,
litecoind, vertcoind, particld) or may require the transaction index to be enabled (dcrd).

Another method of discovering these transactions is to use a public blockchain
explorer.  Not all explorers expose this info through the main user interface so
the API endpoints may need to be used instead.

For Insight-based block explorers, such as the Viacoin block explorer on
[test-]insight.bitpay.com, the Litecoin block explorer on
{insight,testnet}.litecore.io, and the Litecoin block explorer on
{mainnet,testnet}.viacoin.org, the API endpoint `/api/rawtx/<txhash>` can be used
to return a JSON object containing the raw transaction.  For example, here are
links to the four raw transactions published in the example:

## License

These tools are licensed under the [copyfree](http://copyfree.org) ISC License.
