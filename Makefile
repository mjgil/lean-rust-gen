.PHONY: gen check rust-test rust-test-ffi workspace-test no-placeholders rust-validation toolchain-pins first20 remaining-completion publish-dry-run publishing-check

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

remaining-completion:
	./scripts/check-remaining-completion.py

publish-dry-run:
	cargo publish --dry-run -p lean-rust-core-generated
	cargo publish --dry-run -p lean-rust-core-runtime
	cargo publish --dry-run -p lean-rust-core-abi
	cargo publish --dry-run -p lean-rust-core-validate
	cargo publish --dry-run -p lean-rust-core-headers

publishing-check:
	./scripts/check-publishing.sh
