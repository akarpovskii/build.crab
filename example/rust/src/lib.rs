#[no_mangle]
pub extern "C" fn ping_rust(ping: bool) -> bool {
    return !ping;
}
