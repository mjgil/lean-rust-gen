.PHONY: gen check rust-test rust-test-ffi workspace-test no-placeholders rust-validation toolchain-pins first20

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

first20:
	./scripts/check-first-20-completion.py
