# Zapret - One Step, Bypass DPI Barriers

Install Zapret in one step.

## Installation

You can install it as follows.

```shell
curl -fsSL https://raw.github.com/keift/zapret/refs/heads/main/src/install.sh | bash
```

## Uninstall

You can uninstall it as follows.

```shell
curl -fsSL https://raw.github.com/keift/zapret/refs/heads/main/src/uninstall.sh | bash
```

## Screenshots

Here it is.

<img src="./assets/screenshot-1.png" width="100%"/>

## Parameters

Installation settings can be changed in the following ways.

> | Parameter             | Default     | Description                                                                                                                                                                                     |
> | --------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
> | `--strict`            | `false`     | It sets a strict configuration, such as forcing DNS redirection. This means being dependent on the DNS provider.                                                                                |
> | `--dnscrypt`          | `false`     | This tool first checks if DNS-Over-TLS is available. If the DNS-Over-TLS protocol is unavailable, it uses the DNSCrypt protocol. This parameter specifies that it must use DNSCrypt regardless. |
> | `--clean`             | `false`     | This tool sets up a pre-defined list so that Zapret only works on specific domain names. This parameter leaves the list empty, allowing Zapret to identify the domains itself.                  |
> | `--blockcheck-domain` | _automatic_ | This tool finds the correct domain name by sequentially testing blocked websites in different countries for blockcheck. This parameter allows you to specify this domain name yourself.         |
>
> Example:
>
> ```shell
> curl -fsSL https://raw.github.com/keift/zapret/refs/heads/main/src/install.sh | bash -s -- --strict --dnscrypt --clean --blockcheck-domain discord.com
> ```
