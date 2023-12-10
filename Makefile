.PHONY: install
install:
	@mkdir --parents $${HOME}/.local/bin \
	&& mkdir --parents $${HOME}/.config/systemd/user \
	&& cp open_meteo_exporter.sh $${HOME}/.local/bin/ \
	&& chmod +x $${HOME}/.local/bin/open_meteo_exporter.sh \
	&& cp --no-clobber open_meteo_exporter.conf $${HOME}/.config/open_meteo_exporter.conf \
	&& chmod 400 $${HOME}/.config/open_meteo_exporter.conf \
	&& cp open-meteo-exporter.timer $${HOME}/.config/systemd/user/ \
	&& cp open-meteo-exporter.service $${HOME}/.config/systemd/user/ \
	&& systemctl --user enable --now open-meteo-exporter.timer

.PHONY: uninstall
uninstall:
	@rm -f $${HOME}/.local/bin/open_meteo_exporter.sh \
	&& rm -f $${HOME}/.config/open_meteo_exporter.conf \
	&& systemctl --user disable --now open-meteo-exporter.timer \
	&& rm -f $${HOME}/.config/.config/systemd/user/open-meteo-exporter.timer \
	&& rm -f $${HOME}/.config/systemd/user/open-meteo-exporter.service
