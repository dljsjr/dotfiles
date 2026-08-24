function doupdate
    set -lx MISE_MINIMUM_RELEASE_AGE 0s
    if ! sudo -n true > /dev/null 2>&1
        sudo -v || return 1
    end

    if type -q apt-get
        if type -q apt
            sudo apt update
            sudo apt full-upgrade -y
            sudo apt auto-remove -y
        else
            sudo apt-get update
            sudo apt-get dist-upgrade -y
            sudo apt-get auto-remove -y
        end
    end

    if type -q brew
        brew upgrade --yes
        sleep 0.5
        brew autoremove
        sleep 0.5
        brew cleanup
    end

    if type -q mise
        mise self-update --yes
        mise upgrade --bump --yes
    end

    if type -q rustup
        rustup update
    end

    if type -q cargo-install-update
        cargo install-update -a
    end

    if type -q mas && test -n "$(mas outdated 2>/dev/null)"
	    mas upgrade	
    end

    if type -q fwupdmgr; and fwupdmgr get-devices 2>/dev/null | grep -v -q "No hardware detected"
        fwupdmgr get-updates
    end
end
