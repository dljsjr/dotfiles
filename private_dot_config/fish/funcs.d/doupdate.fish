function doupdate
    if type -q apt-get
        if type -q apt
            if ! sudo -n apt update >/dev/null 2>&1
                sudo -v
            end
            sudo apt update
            sudo apt full-upgrade -y
            sudo apt auto-remove -y
        else
            if ! sudo -n apt-get update >/dev/null 2>&1
                sudo -v
            end
            sudo apt-get update
            sudo apt-get dist-upgrade -y
            sudo apt-get auto-remove -y
        end
    end

    if type -q brew
        brew upgrade
        sleep 0.5
        brew autoremove
        sleep 0.5
        brew cleanup
    end

    if type -q mise
	mise self-update
	mise upgrade --bump
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
