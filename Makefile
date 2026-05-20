.PHONY: gen check rust-test no-placeholders rust-validation toolchain-pins

gen:
	./scripts/gen.sh

check:
	./scripts/check.sh

rust-test:
	cd rust && cargo test

no-placeholders:
	./scripts/check-no-placeholders.sh

toolchain-pins:
	./scripts/check-toolchain-pins.sh

rust-validation:
	./scripts/check-rust-validation.sh
