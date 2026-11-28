# frozen_string_literal: true

module Library
  # Fixed lists used to qualify guides (see docs/LIBRARY_INVENTORY_PLAN.md, section 4.0).
  # Values are Polish names stored as is, so they are searchable and need no mapping.
  module Catalog
    DISCIPLINES = %w[
      wspinaczkowy skiturowy trekkingowy alpinistyczny bouldering
      lodowy jaskiniowy ferraty rowerowy inny
    ].freeze

    COUNTRIES = %w[
      Polska Słowacja Czechy Austria Niemcy Szwajcaria Włochy Francja Hiszpania
      Andora Portugalia Słowenia Chorwacja Czarnogóra Albania Bułgaria Rumunia
      Ukraina Grecja Turcja Gruzja Norwegia Szwecja Islandia Maroko Tanzania
      Kenia Nepal Indie Pakistan Chiny Kirgistan Kazachstan Peru Boliwia
      Argentyna Chile Ekwador Meksyk USA Kanada Jordania Antarktyda
    ].freeze
  end
end
