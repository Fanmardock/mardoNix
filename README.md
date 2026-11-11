# Dendritic Example Repo

Videos can be found [on my channel](https://www.youtube.com/@Adumh00man).

This is supposed to be a minimal dendritic nix configuration, some things may be
deliberately missing or broken for demonstrative purposes in some commits.

This repo will most likely not work on bare metal, using a vm is reccomended for
tinkering and getting your head around things. This can be done with the following command:

```bash
nixos-rebuild build-vm --flake .#host
```

Some commits will require impure evaluation, although I will keep this to a minimum.

Comments have been placed outside of filming to explain what parts of the code do,
as this is a mostly "for reference" repo.

This repo also depends on [this hyprland config](https://git.voidarc.co.uk/adumh00man/hyprland-dendritic),
which is self contained, but contains some more useful wrapper examples.

Any issues or typos or whatever can be reported via [email](mailto://admin@voidarc.co.uk)
or [matrix](https://matrix.to/#/@admin:voidarc.co.uk). Lots of love <3
