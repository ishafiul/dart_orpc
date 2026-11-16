//! HTTP/1.1 wire handling: request heads, request bodies and answers.

pub mod body;
pub mod head;
pub mod render;

/// Whether the comma separated `value` contains `token`, ignoring case.
#[must_use]
pub fn has_token(value: &[u8], token: &str) -> bool {
    value
        .split(|&c| c == b',')
        .any(|t| t.trim_ascii().eq_ignore_ascii_case(token.as_bytes()))
}

/// A length: ASCII digits only, with spaces or tabs around. Not `+5`, not
/// `5, 5`, not other white space.
#[must_use]
pub fn parse_length(value: &[u8]) -> Option<u64> {
    let value = value.trim_ascii();
    if value.is_empty() || !value.iter().all(u8::is_ascii_digit) {
        return None;
    }
    value.iter().try_fold(0u64, |n, &digit| {
        n.checked_mul(10)?.checked_add(u64::from(digit - b'0'))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lengths_are_digits_only() {
        assert_eq!(parse_length(b" 42\t"), Some(42));
        for bad in [
            &b""[..],
            b"+5",
            b"-1",
            b"5, 5",
            b"0x10",
            b"1\x0b",
            b"99999999999999999999999",
        ] {
            assert_eq!(parse_length(bad), None, "{bad:?}");
        }
    }

    #[test]
    fn tokens_ignore_case_and_spaces() {
        assert!(has_token(b"keep-alive, Upgrade", "upgrade"));
        assert!(!has_token(b"upgrader", "upgrade"));
    }
}
