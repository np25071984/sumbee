package dev.sumbee.ui

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/**
 * Every translation has every translatable English string, with the same placeholders. A string
 * left out would fall back to English mid-sentence; a lost %1$s would drop the child's name.
 */
class TranslationsTest {

    private val res = File("src/main/res")
    private val languages = listOf("es")

    @Test
    fun everyLanguageHasEveryStringWithTheSamePlaceholders() {
        val english = strings(File(res, "values/strings.xml"), translatableOnly = true)
        for (lang in languages) {
            val translated = strings(File(res, "values-$lang/strings.xml"), translatableOnly = false)
            assertEquals("$lang: string names", english.keys, translated.keys)
            for ((name, text) in english) {
                assertEquals("$lang: placeholders in $name", placeholders(text), placeholders(translated.getValue(name)))
            }
        }
    }

    private fun strings(file: File, translatableOnly: Boolean): Map<String, String> {
        val nodes = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file).getElementsByTagName("string")
        return (0 until nodes.length).map { nodes.item(it) as org.w3c.dom.Element }
            .filter { !translatableOnly || it.getAttribute("translatable") != "false" }
            .associate { it.getAttribute("name") to it.textContent }
    }

    private fun placeholders(text: String) = Regex("%\\d+\\$[sd]").findAll(text).map { it.value }.sorted().toList()
}
