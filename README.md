# Zapret - One Step, Bypass DPI Barriers

We save you from the hassle of setting up Zapret and make it easy to overcome all DPI access restrictions with a single command.

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

> | Parameter             | Default     | Description                                                                                                                                                                             |
> | --------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
> | `--blockcheck-domain` | _automatic_ | This tool finds the correct domain name by sequentially testing blocked websites in different countries for blockcheck. This parameter allows you to specify this domain name yourself. |
>
> Example:
>
> ```shell
> curl -fsSL https://raw.github.com/keift/zapret/refs/heads/main/src/install.sh | bash -s -- --blockcheck-domain discord.com
> ```
