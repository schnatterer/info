/* Navigate basing one the browser language: 
 *  Only on first visit, and when no language is in URL. */
const browserLangString = (navigator.language || navigator.userLanguage) 
const browserLang = browserLangString ? browserLangString.substring(0, 2) : ''
const docLang = document.documentElement.lang
const selectedLang = localStorage.getItem('selectedLanguage')
if (!selectedLang
    && docLang === 'en'
    && browserLang !== 'en'
    && browserLang === 'de') {
    localStorage.setItem('selectedLanguage', browserLang);
    window.location = `${window.location.origin}/${browserLang === 'en' ? '' : browserLang}${window.location.pathname}`
}