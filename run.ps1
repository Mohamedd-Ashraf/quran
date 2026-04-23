$url = "https://mp3quran.net/api/v3/reciters?language=ar"
$response = Invoke-RestMethod -Uri $url
$mapping = [ordered]@{
    'ar.qiraat.qalon'='https://server10.mp3quran.net/trablsi/'
    'ar.qiraat.bazi'='https://server16.mp3quran.net/deban/Rewayat-Albizi-A-n-Ibn-Katheer/'
    'ar.qiraat.qunbol'='https://server16.mp3quran.net/deban/Rewayat-Qunbol-A-n-Ibn-Katheer/'
    'ar.qiraat.duri.abuamr'='https://server16.mp3quran.net/deban/Rewayat-Aldori-A-n-Abi-Amr/'
    'ar.qiraat.ibndhakwan'='https://server14.mp3quran.net/muftah_sultany/Rewayat_Ibn-Thakwan-A-n-Ibn-Amer/'
    'ar.qiraat.shuba'='https://server16.mp3quran.net/deban/Rewayat-Sho-bah-A-n-Asim/'
    'ar.qiraat.duri.kisai'='https://server14.mp3quran.net/muftah_sultany/Rewayat-AlDorai-A-n-Al-Kisa-ai/'
    'ar.qiraat.warsh.azraq'='https://server16.mp3quran.net/deban/Rewayat-Warsh-A-n-Nafi-Men-Tariq-Alazraq/'
    'ar.qiraat.sosi.abuamr'='https://server16.mp3quran.net/soufi/Rewayat-Assosi-A-n-Abi-Amr/'
    'ar.qiraat.khalaf.hamza'='https://server16.mp3quran.net/soufi/Rewayat-Khalaf-A-n-Hamzah/'
    'ar.qiraat.husary.qalon'='https://server13.mp3quran.net/husr/Rewayat-Qalon-A-n-Nafi/'
    'ar.qiraat.husary.warsh'='https://server13.mp3quran.net/husr/Rewayat-Warsh-A-n-Nafi/'
    'ar.qiraat.husary.duri'='https://server13.mp3quran.net/husr/Rewayat-Aldori-A-n-Abi-Amr/'
    'ar.qiraat.huthifi.qalon'='https://server9.mp3quran.net/huthifi_qalon/'
    'ar.qiraat.koshi.warsh'='https://server11.mp3quran.net/koshi/'
    'ar.qiraat.yasseen.warsh'='https://server11.mp3quran.net/qari/'
    'ar.qiraat.qazabri.warsh'='https://server9.mp3quran.net/omar_warsh/'
    'ar.qiraat.dokali.qalon'='https://server7.mp3quran.net/dokali/'
    'ar.qiraat.okasha.bazi'='https://server16.mp3quran.net/okasha/Rewayat-Albizi-A-n-Ibn-Katheer/'
    'ar.khaledjleel'='https://server10.mp3quran.net/jleel/'
    'ar.raadialkurdi'='https://server6.mp3quran.net/kurdi/'
    'ar.abdulaziahahmad'='https://server11.mp3quran.net/a_ahmed/'
}
$results = foreach ($edition in $mapping.Keys) {
    $targetUrl = $mapping[$edition].TrimEnd('/')
    foreach ($reciter in $response.reciters) {
        foreach ($moshaf in $reciter.moshaf) {
            if ($moshaf.server.TrimEnd('/') -eq $targetUrl) {
                $surahs = $moshaf.surah_list.Split(',') | Where-Object { $_ -ne "" } | ForEach-Object { [int]$_ } | Sort-Object
                [PSCustomObject]@{
                    edition = $edition
                    reciter = $reciter.name
                    count = $surahs.Count
                    full = ($surahs.Count -eq 114)
                    surahs = $surahs
                }
                break
            }
        }
    }
}
$results | ForEach-Object { "{0} | {1} | {2} | Full: {3}" -f $_.edition, $_.reciter, $_.count, $_.full }
Write-Host "
PARTIAL COVERAGE:"
$results | Where-Object { -not $_.full } | ForEach-Object { "{0}: {1}" -f $_.edition, ($_.surahs -join ",") }
