fn main() {
    println!(
        "I'm using the library: {:?}",
        hello_world::add(1, 2)
    );
}

#[cfg(test)]
mod tests {
    #[test]
    fn bin_test() {
        let result = hello_world::add(1, 1);
        assert_eq!(result, 2);
    }
}
