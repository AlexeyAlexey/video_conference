defmodule VideoConference.AdminPortal.StreamServers.Countries do
  @moduledoc """
  The fixed set of countries supported as a stream server location.

  Maps ISO 3166-1 alpha-2 codes (stored on `StreamServer.country`) to
  display names, and derives flag emoji from the code itself — a flag is
  just the two regional indicator symbols matching the code's letters,
  so no flag assets or mapping table are needed.
  """

  @names %{
    "ad" => "Andorra",
    "ae" => "United Arab Emirates",
    "af" => "Afghanistan",
    "ag" => "Antigua and Barbuda",
    "ai" => "Anguilla",
    "al" => "Albania",
    "am" => "Armenia",
    "ao" => "Angola",
    "aq" => "Antarctica",
    "ar" => "Argentina",
    "as" => "American Samoa",
    "at" => "Austria",
    "au" => "Australia",
    "aw" => "Aruba",
    "ax" => "Åland Islands",
    "az" => "Azerbaijan",
    "ba" => "Bosnia and Herzegovina",
    "bb" => "Barbados",
    "bd" => "Bangladesh",
    "be" => "Belgium",
    "bf" => "Burkina Faso",
    "bg" => "Bulgaria",
    "bh" => "Bahrain",
    "bi" => "Burundi",
    "bj" => "Benin",
    "bl" => "Saint Barthélemy",
    "bm" => "Bermuda",
    "bn" => "Brunei",
    "bo" => "Bolivia",
    "bq" => "Caribbean Netherlands",
    "br" => "Brazil",
    "bs" => "Bahamas",
    "bt" => "Bhutan",
    "bv" => "Bouvet Island",
    "bw" => "Botswana",
    "by" => "Belarus",
    "bz" => "Belize",
    "ca" => "Canada",
    "cc" => "Cocos (Keeling) Islands",
    "cd" => "DR Congo",
    "cf" => "Central African Republic",
    "cg" => "Republic of the Congo",
    "ch" => "Switzerland",
    "ci" => "Côte d'Ivoire",
    "ck" => "Cook Islands",
    "cl" => "Chile",
    "cm" => "Cameroon",
    "cn" => "China",
    "co" => "Colombia",
    "cr" => "Costa Rica",
    "cu" => "Cuba",
    "cv" => "Cape Verde",
    "cw" => "Curaçao",
    "cx" => "Christmas Island",
    "cy" => "Cyprus",
    "cz" => "Czechia",
    "de" => "Germany",
    "dj" => "Djibouti",
    "dk" => "Denmark",
    "dm" => "Dominica",
    "do" => "Dominican Republic",
    "dz" => "Algeria",
    "ec" => "Ecuador",
    "ee" => "Estonia",
    "eg" => "Egypt",
    "eh" => "Western Sahara",
    "er" => "Eritrea",
    "es" => "Spain",
    "et" => "Ethiopia",
    "fi" => "Finland",
    "fj" => "Fiji",
    "fk" => "Falkland Islands",
    "fm" => "Micronesia",
    "fo" => "Faroe Islands",
    "fr" => "France",
    "ga" => "Gabon",
    "gb" => "United Kingdom",
    "gd" => "Grenada",
    "ge" => "Georgia",
    "gf" => "French Guiana",
    "gg" => "Guernsey",
    "gh" => "Ghana",
    "gi" => "Gibraltar",
    "gl" => "Greenland",
    "gm" => "Gambia",
    "gn" => "Guinea",
    "gp" => "Guadeloupe",
    "gq" => "Equatorial Guinea",
    "gr" => "Greece",
    "gs" => "South Georgia",
    "gt" => "Guatemala",
    "gu" => "Guam",
    "gw" => "Guinea-Bissau",
    "gy" => "Guyana",
    "hk" => "Hong Kong",
    "hm" => "Heard Island and McDonald Islands",
    "hn" => "Honduras",
    "hr" => "Croatia",
    "ht" => "Haiti",
    "hu" => "Hungary",
    "id" => "Indonesia",
    "ie" => "Ireland",
    "il" => "Israel",
    "im" => "Isle of Man",
    "in" => "India",
    "io" => "British Indian Ocean Territory",
    "iq" => "Iraq",
    "ir" => "Iran",
    "is" => "Iceland",
    "it" => "Italy",
    "je" => "Jersey",
    "jm" => "Jamaica",
    "jo" => "Jordan",
    "jp" => "Japan",
    "ke" => "Kenya",
    "kg" => "Kyrgyzstan",
    "kh" => "Cambodia",
    "ki" => "Kiribati",
    "km" => "Comoros",
    "kn" => "Saint Kitts and Nevis",
    "kp" => "North Korea",
    "kr" => "South Korea",
    "kw" => "Kuwait",
    "ky" => "Cayman Islands",
    "kz" => "Kazakhstan",
    "la" => "Laos",
    "lb" => "Lebanon",
    "lc" => "Saint Lucia",
    "li" => "Liechtenstein",
    "lk" => "Sri Lanka",
    "lr" => "Liberia",
    "ls" => "Lesotho",
    "lt" => "Lithuania",
    "lu" => "Luxembourg",
    "lv" => "Latvia",
    "ly" => "Libya",
    "ma" => "Morocco",
    "mc" => "Monaco",
    "md" => "Moldova",
    "me" => "Montenegro",
    "mf" => "Saint Martin",
    "mg" => "Madagascar",
    "mh" => "Marshall Islands",
    "mk" => "North Macedonia",
    "ml" => "Mali",
    "mm" => "Myanmar",
    "mn" => "Mongolia",
    "mo" => "Macau",
    "mp" => "Northern Mariana Islands",
    "mq" => "Martinique",
    "mr" => "Mauritania",
    "ms" => "Montserrat",
    "mt" => "Malta",
    "mu" => "Mauritius",
    "mv" => "Maldives",
    "mw" => "Malawi",
    "mx" => "Mexico",
    "my" => "Malaysia",
    "mz" => "Mozambique",
    "na" => "Namibia",
    "nc" => "New Caledonia",
    "ne" => "Niger",
    "nf" => "Norfolk Island",
    "ng" => "Nigeria",
    "ni" => "Nicaragua",
    "nl" => "Netherlands",
    "no" => "Norway",
    "np" => "Nepal",
    "nr" => "Nauru",
    "nu" => "Niue",
    "nz" => "New Zealand",
    "om" => "Oman",
    "pa" => "Panama",
    "pe" => "Peru",
    "pf" => "French Polynesia",
    "pg" => "Papua New Guinea",
    "ph" => "Philippines",
    "pk" => "Pakistan",
    "pl" => "Poland",
    "pm" => "Saint Pierre and Miquelon",
    "pn" => "Pitcairn Islands",
    "pr" => "Puerto Rico",
    "ps" => "Palestine",
    "pt" => "Portugal",
    "pw" => "Palau",
    "py" => "Paraguay",
    "qa" => "Qatar",
    "re" => "Réunion",
    "ro" => "Romania",
    "rs" => "Serbia",
    "ru" => "Russia",
    "rw" => "Rwanda",
    "sa" => "Saudi Arabia",
    "sb" => "Solomon Islands",
    "sc" => "Seychelles",
    "sd" => "Sudan",
    "se" => "Sweden",
    "sg" => "Singapore",
    "sh" => "Saint Helena",
    "si" => "Slovenia",
    "sj" => "Svalbard and Jan Mayen",
    "sk" => "Slovakia",
    "sl" => "Sierra Leone",
    "sm" => "San Marino",
    "sn" => "Senegal",
    "so" => "Somalia",
    "sr" => "Suriname",
    "ss" => "South Sudan",
    "st" => "São Tomé and Príncipe",
    "sv" => "El Salvador",
    "sx" => "Sint Maarten",
    "sy" => "Syria",
    "sz" => "Eswatini",
    "tc" => "Turks and Caicos Islands",
    "td" => "Chad",
    "tf" => "French Southern Territories",
    "tg" => "Togo",
    "th" => "Thailand",
    "tj" => "Tajikistan",
    "tk" => "Tokelau",
    "tl" => "Timor-Leste",
    "tm" => "Turkmenistan",
    "tn" => "Tunisia",
    "to" => "Tonga",
    "tr" => "Turkey",
    "tt" => "Trinidad and Tobago",
    "tv" => "Tuvalu",
    "tw" => "Taiwan",
    "tz" => "Tanzania",
    "ua" => "Ukraine",
    "ug" => "Uganda",
    "um" => "U.S. Minor Outlying Islands",
    "us" => "United States",
    "uy" => "Uruguay",
    "uz" => "Uzbekistan",
    "va" => "Vatican City",
    "vc" => "Saint Vincent and the Grenadines",
    "ve" => "Venezuela",
    "vg" => "British Virgin Islands",
    "vi" => "U.S. Virgin Islands",
    "vn" => "Vietnam",
    "vu" => "Vanuatu",
    "wf" => "Wallis and Futuna",
    "ws" => "Samoa",
    "ye" => "Yemen",
    "yt" => "Mayotte",
    "za" => "South Africa",
    "zm" => "Zambia",
    "zw" => "Zimbabwe"
  }

  @doc """
  Returns the supported ISO alpha-2 codes.
  """
  def codes, do: Map.keys(@names)

  @doc """
  Returns the display name for a supported code, or `nil`.
  """
  def name(code), do: Map.get(@names, code)

  @doc """
  Returns the flag emoji for a supported code, or `nil` for `nil` or an
  unsupported code.
  """
  def flag(nil), do: nil

  def flag(code) when is_binary(code) do
    if Map.has_key?(@names, code) do
      code
      |> String.upcase()
      |> String.to_charlist()
      |> Enum.map(&(&1 - ?A + 0x1F1E6))
      |> List.to_string()
    end
  end

  @doc """
  Returns the `"flag name"` select label for a supported code.
  """
  def option_label(code) do
    case name(code) do
      nil -> code
      name -> "#{flag(code)} #{name}"
    end
  end

  @doc """
  Returns `{label, code}` pairs for a select input, sorted by country
  name. Labels are the flag emoji followed by the country name. When
  `query` is given, only countries whose name or code contains it
  (case-insensitive) are returned.
  """
  def options_for_select(query \\ "") do
    query = String.downcase(String.trim(query))

    @names
    |> Enum.filter(fn {code, name} ->
      query == "" or String.contains?(String.downcase(name), query) or
        String.contains?(code, query)
    end)
    |> Enum.map(fn {code, name} -> {"#{flag(code)} #{name}", code} end)
    |> Enum.sort()
  end
end
