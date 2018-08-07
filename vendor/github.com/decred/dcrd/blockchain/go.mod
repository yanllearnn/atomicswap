module github.com/decred/dcrd/blockchain

require (
	github.com/decred/dcrd/blockchain/stake v1.0.0
	github.com/decred/dcrd/chaincfg v1.0.1
	github.com/decred/dcrd/chaincfg/chainhash v1.0.1
	github.com/decred/dcrd/database v1.0.0
	github.com/decred/dcrd/dcrec v0.0.0-20180801202239-0761de129164
	github.com/decred/dcrd/dcrec/edwards v0.0.0-20180721031028-5369a485acf6
	github.com/decred/dcrd/dcrec/secp256k1 v1.0.0
	github.com/decred/dcrd/dcrjson v1.0.0
	github.com/decred/dcrd/dcrutil v1.0.0
	github.com/decred/dcrd/gcs v1.0.0
	github.com/decred/dcrd/txscript v1.0.0
	github.com/decred/dcrd/wire v1.0.1
	github.com/decred/slog v1.0.0
)

replace (
	github.com/decred/dcrd/blockchain/stake => ./stake
	github.com/decred/dcrd/chaincfg => ../chaincfg
	github.com/decred/dcrd/chaincfg/chainhash => ../chaincfg/chainhash
	github.com/decred/dcrd/database => ../database
	github.com/decred/dcrd/dcrec => ../dcrec
	github.com/decred/dcrd/dcrec/edwards => ../dcrec/edwards
	github.com/decred/dcrd/dcrec/secp256k1 => ../dcrec/secp256k1
	github.com/decred/dcrd/dcrjson => ../dcrjson
	github.com/decred/dcrd/dcrutil => ../dcrutil
	github.com/decred/dcrd/gcs => ../gcs
	github.com/decred/dcrd/txscript => ../txscript
	github.com/decred/dcrd/wire => ../wire
)
