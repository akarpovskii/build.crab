pub fn add(a: u8, b: u8) -> u8 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lib_test() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
