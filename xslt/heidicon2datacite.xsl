<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://datacite.org/schema/kernel-4">
  <xsl:output method="xml" encoding="utf-8"/>

  <!--
    heidICON-Schema -> DataCite Version 4.1

    Bislang werden nur die Sprachvarianten de-DE und en-US berücksichtigt
  -->

  <xsl:template match="/">
    <resource
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://datacite.org/schema/kernel-4 http://schema.datacite.org/meta/kernel-4.1/metadata.xsd">
      <xsl:apply-templates select="//objects/objekte" />
      <xsl:apply-templates select="//objects/ressourcen" />
    </resource>
  </xsl:template>

  <!-- Datensätze vom Typ Gegenstand/Werk/Objekt -->
  <xsl:template match="objekte">
    <identifier identifierType="DOI">___DOI_PLACEHOLDER___</identifier>

    <!-- creator ist bei Datacite Pflichtfeld: Ggf. als NN melden -->
    <xsl:choose>
      <xsl:when test="count(_nested__objekte__obj_autoren/objekte__obj_autoren) or count(_nested__objekte__obj_autoren_lok/objekte__obj_autoren_lok)">
        <creators>
          <xsl:for-each select="_nested__objekte__obj_autoren/objekte__obj_autoren">
            <creator>
              <creatorName nameType="Personal"><xsl:value-of select="custom/string[@name='conceptName']" /></creatorName>
            </creator>
          </xsl:for-each>
          <xsl:for-each select="_nested__objekte__obj_autoren_lok/objekte__obj_autoren_lok">
            <creator>
              <xsl:choose>
                <!-- TODO: Bessere Unterstützung Mehrsprachigkeit -->
                <xsl:when test="obj_autor_lok/lokal_klass_person/_standard/de-DE">
                  <creatorName nameType="Personal"><xsl:value-of select="obj_autor_lok/lokal_klass_person/_standard/de-DE" /></creatorName>
                </xsl:when>
                <xsl:otherwise>
                  <creatorName nameType="Personal"><xsl:value-of select="obj_autor_lok/lokal_klass_person/_standard/en-US" /></creatorName>
                </xsl:otherwise>
              </xsl:choose>
            </creator>
          </xsl:for-each>
        </creators>
      </xsl:when>
      <xsl:otherwise>
        <creators>
          <creator>
            <creatorName nameType="Personal">NN</creatorName>
          </creator>
        </creators>
      </xsl:otherwise>
    </xsl:choose>

    <titles>
      <xsl:if test="obj_titel/de-DE and string-length(obj_titel/de-DE)"><title xml:lang="de-DE"><xsl:value-of select="obj_titel/de-DE" /></title></xsl:if>
      <xsl:if test="obj_titel/en-US and string-length(obj_titel/en-US)"><title xml:lang="en-US"><xsl:value-of select="obj_titel/en-US" /></title></xsl:if>
      <!-- TODO: Weitere Titel -->
    </titles>

    <publisher>heidICON, Heidelberg University Library</publisher>

    <publicationYear><xsl:value-of select="substring(_last_modified,1,4)" /></publicationYear>

    <xsl:if test="count(_nested__objekte__obj_schlagworte/objekte__obj_schlagworte) or count(_nested__objekte__obj_schlagworte_lok/objekte__obj_schlagworte_lok)">
      <subjects>
        <xsl:for-each select="_nested__objekte__obj_schlagworte/objekte__obj_schlagworte">
          <subject xml:lang="de-DE"><xsl:value-of select="custom/string[@name='conceptName']" /></subject>
        </xsl:for-each>
        <xsl:for-each select="_nested__objekte__obj_schlagworte_lok/objekte__obj_schlagworte_lok">
          <xsl:if test="obj_schlagwort_lok/lokal_klass_sach/_standard/de-DE and string-length(obj_schlagwort_lok/lokal_klass_sach/_standard/de-DE)"><subject><xsl:value-of select="obj_schlagwort_lok/lokal_klass_sach/_standard/de-DE" /></subject></xsl:if>
          <xsl:if test="obj_schlagwort_lok/lokal_klass_sach/_standard/en-US and string-length(obj_schlagwort_lok/lokal_klass_sach/_standard/en-US)"><subject><xsl:value-of select="obj_schlagwort_lok/lokal_klass_sach/_standard/en-US" /></subject></xsl:if>
        </xsl:for-each>
      </subjects>
    </xsl:if>

    <xsl:call-template name="asset">
      <xsl:with-param name="assetnode" select="_reverse_nested__ressourcen__lk_objekt_id/*[local-name()='ressourcen'][1]/asset" />
    </xsl:call-template>

    <alternateIdentifiers>
      <alternateIdentifier alternateIdentifierType="URL">https://heidicon.ub.uni-heidelberg.de/detail/<xsl:value-of select="_system_object_id" /></alternateIdentifier>
    </alternateIdentifiers>

    <rightsList>
      <xsl:for-each select="_reverse_nested__ressourcen__lk_objekt_id/ressourcen/res_lizenz/lizenzen">
        <xsl:if test="not(preceding::res_lizenz/lizenzen/_id=_id)">
          <rights><xsl:attribute name="rightsURI"><xsl:value-of select="custom[@name='link']/string[@name='url']" /></xsl:attribute><xsl:value-of select="bezeichnung/en-US" /></rights>
        </xsl:if>
      </xsl:for-each>
    </rightsList>

    <xsl:if test="obj_beschreibung and string-length(obj_beschreibung)">
      <descriptions>
        <xsl:if test="obj_beschreibung/de-DE and string-length(obj_beschreibung/de-DE)"><description xml:lang="de-DE" descriptionType="Abstract"><xsl:value-of select="obj_beschreibung/de-DE" /></description></xsl:if>
        <xsl:if test="obj_beschreibung/en-US and string-length(obj_beschreibung/en-US)"><description xml:lang="en-US" descriptionType="Abstract"><xsl:value-of select="obj_beschreibung/en-US" /></description></xsl:if>
      </descriptions>
    </xsl:if>
  </xsl:template>

  <!-- Datensätze vom Typ Aufnahme/Reproduktion -->
  <xsl:template match="ressourcen">
    <identifier identifierType="DOI">___DOI_PLACEHOLDER___</identifier>

    <titles>
      <xsl:if test="lk_objekt_id/objekte/_standard/de-DE and string-length(lk_objekt_id/objekte/_standard/de-DE)"><title xml:lang="de-DE"><xsl:value-of select="lk_objekt_id/objekte/_standard/de-DE" /></title></xsl:if>
      <xsl:if test="lk_objekt_id/objekte/_standard/en-US and string-length(lk_objekt_id/objekte/_standard/en-US)"><title xml:lang="en-US"><xsl:value-of select="lk_objekt_id/objekte/_standard/en-US" /></title></xsl:if>
      <!-- TODO: Weitere Titel -->
    </titles>

    <!-- creator ist bei Datacite Pflichtfeld: Ggf. als NN melden -->
    <xsl:choose>
      <xsl:when test="count(_nested__ressourcen__res_autoren/ressourcen__res_autoren) or count(_nested__ressourcen__res_autoren_lok/ressourcen__res_autoren_lok)">
        <creators>
          <xsl:for-each select="_nested__ressourcen__res_autoren/ressourcen__res_autoren">
            <creator>
              <creatorName nameType="Personal"><xsl:value-of select="custom/string[@name='conceptName']" /></creatorName>
            </creator>
          </xsl:for-each>
          <xsl:for-each select="_nested__ressourcen__res_autoren_lok/ressourcen__res_autoren_lok">
            <creator>
              <creatorName nameType="Personal"><xsl:value-of select="res_autor_lok" /></creatorName>
            </creator>
          </xsl:for-each>
        </creators>
      </xsl:when>
      <xsl:otherwise>
        <creators>
          <creator>
            <creatorName nameType="Personal">NN</creatorName>
          </creator>
        </creators>
      </xsl:otherwise>
    </xsl:choose>

    <publisher>heidICON, Heidelberg University Library</publisher>

    <publicationYear><xsl:value-of select="substring(_last_modified,1,4)" /></publicationYear>

    <xsl:call-template name="asset"><xsl:with-param name="assetnode" select="asset" /></xsl:call-template>

    <alternateIdentifiers>
      <alternateIdentifier alternateIdentifierType="URL">https://heidicon.ub.uni-heidelberg.de/detail/<xsl:value-of select="_system_object_id" /></alternateIdentifier>
    </alternateIdentifiers>

    <rightsList>
      <xsl:for-each select="res_lizenz/lizenzen">
        <rights><xsl:attribute name="rightsURI"><xsl:value-of select="custom[@name='link']/string[@name='url']" /></xsl:attribute><xsl:value-of select="bezeichnung/en-US" /></rights>
      </xsl:for-each>
    </rightsList>
  </xsl:template>

  <xsl:template name="asset">
    <xsl:param name="assetnode" />
    <resourceType>
      <xsl:choose>
        <xsl:when test="$assetnode/files/*[local-name()='file'][1]/class='image'"><xsl:attribute name="resourceTypeGeneral">Image</xsl:attribute>Image</xsl:when>
        <xsl:when test="$assetnode/files/*[local-name()='file'][1]/class='audio'"><xsl:attribute name="resourceTypeGeneral">Sound</xsl:attribute>Audio</xsl:when>
        <xsl:when test="$assetnode/files/*[local-name()='file'][1]/class='video'"><xsl:attribute name="resourceTypeGeneral">Audiovisual</xsl:attribute>Video</xsl:when>
        <xsl:when test="$assetnode/files/*[local-name()='file'][1]/class='office'"><xsl:attribute name="resourceTypeGeneral">Text</xsl:attribute>Text/Office</xsl:when>
        <xsl:otherwise><xsl:attribute name="resourceTypeGeneral">Other</xsl:attribute>Other</xsl:otherwise>
      </xsl:choose>
    </resourceType>
  </xsl:template>
</xsl:stylesheet>
