.PHONY: gen check rust-test rust-test-ffi no-placeholders rust-validation toolchain-pins

gen:
	./scripts/gen.sh

check:
	./scripts/check.sh

rust-test:
	cd rust && cargo test

rust-test-ffi:
	cd rust && cargo test --features ffi

no-placeholders:
	./scripts/check-no-placeholders.sh

toolchain-pins:
	./scripts/check-toolchain-pins.sh

rust-validation:
	./scripts/check-rust-validation.sh

rust-test-ffi:
	cd rust && cargo test --features ffi
rust-test-ffi:
	cd rust && cargo test --features ffi
