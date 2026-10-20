# @summary A SHA-256 checksum as 64 lowercase hexadecimal digits.
type Curator::Sha256 = Pattern[/\A[0-9a-f]{64}\z/]
