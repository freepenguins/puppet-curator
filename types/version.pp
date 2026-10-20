# @summary A Curator release number as published on PyPI, such as `8.0.21`.
type Curator::Version = Pattern[/\A[0-9]+(\.[0-9]+)+([a-z0-9.+!-]*)\z/]
