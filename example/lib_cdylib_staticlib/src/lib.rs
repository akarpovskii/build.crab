use std::io::Write;

#[no_mangle]
pub extern "C" fn ping_rust(ping: bool) -> bool {
    let _ = std::io::stdout().write("rust".as_bytes());
    return !ping;
}
