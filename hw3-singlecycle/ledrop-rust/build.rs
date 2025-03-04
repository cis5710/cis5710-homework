fn main() {
    // tell cargo to rebuild when the linker script `memory.x` changes
    println!("cargo::rerun-if-changed=memory.x");
}
