.PHONY: gen check rust-test rust-test-ffi workspace-test no-placeholders rust-validation toolchain-pins

gen:
	./scripts/gen.sh

check:
	./scripts/check.sh

rust-test:
	cargo test -p lean-rust-core-generated

rust-test-ffi:
	cargo test -p lean-rust-core-generated --features ffi

workspace-test:
	cargo test --workspace

no-placeholders:
	./scripts/check-no-placeholders.sh

toolchain-pins:
	./scripts/check-toolchain-pins.sh

rust-validation:
	./scripts/check-rust-validation.sh
