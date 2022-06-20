/* Copyright (c) 2001-2021, David A. Clunie DBA Pixelmed Publishing. All rights reserved. */

import javax.json.Json;
import javax.json.JsonArray;
import javax.json.JsonNumber;
import javax.json.JsonObject;
import javax.json.JsonReader;
import javax.json.JsonString;
import javax.json.JsonValue;

import java.io.*;
import java.util.*;

public class CPTACJSONAPIClinicalData {

	public class SlideMetadata {
		String slide_id;
		String specimen_id;
		String tumor_code;
		String case_id;
		String gender;
		String age;
		String height_in_cm;
		String weight_in_kg;
		String race;
		String ethnicity;
		String tumor_site;
		String tissue_type;

		public SlideMetadata(
			String slide_id,
			String specimen_id,
			String tumor_code,
			String case_id,
			String gender,
			String age,
			String height_in_cm,
			String weight_in_kg,
			String race,
			String ethnicity,
			String tumor_site,
			String tissue_type
		) {
				this.slide_id = slide_id;
			 this.specimen_id = specimen_id;
			  this.tumor_code = tumor_code;
				 this.case_id = case_id;
				  this.gender = gender;
			         this.age = age;
			this.height_in_cm = height_in_cm;
			this.weight_in_kg = weight_in_kg;
					this.race = race;
			   this.ethnicity = ethnicity;
			  this.tumor_site = tumor_site;
			  this.tissue_type = tissue_type;

			//System.err.println(slide_id);
		}

		public String toString() {
			StringBuffer buf = new StringBuffer();
			buf.append("slide_id = "); buf.append(slide_id);  buf.append("\n");
			
			buf.append("\tspecimen_id = ");  buf.append(specimen_id);  buf.append("\n");
			buf.append("\ttumor_code = ");   buf.append(tumor_code);  buf.append("\n");
			buf.append("\tcase_id = ");      buf.append(case_id);  buf.append("\n");
			buf.append("\tgender = ");       buf.append(gender);  buf.append("\n");
			buf.append("\tage = ");          buf.append(age);  buf.append("\n");
			buf.append("\theight_in_cm = "); buf.append(height_in_cm);  buf.append("\n");
			buf.append("\tweight_in_kg = "); buf.append(weight_in_kg);  buf.append("\n");
			buf.append("\trace = ");         buf.append(race);  buf.append("\n");
			buf.append("\tethnicity = ");    buf.append(ethnicity);  buf.append("\n");
			buf.append("\ttumor_site = ");   buf.append(tumor_site);  buf.append("\n");
			buf.append("\ttissue_type = ");  buf.append(tissue_type);  buf.append("\n");

			return buf.toString();
		}

		public String toCSV() {
			StringBuffer buf = new StringBuffer();
			buf.append(slide_id);  buf.append(",");
			buf.append(specimen_id);  buf.append(",");
			buf.append(tumor_code);  buf.append(",");
			buf.append(case_id);  buf.append(",");
			buf.append(gender);  buf.append(",");
			buf.append(age);  buf.append(",");
			buf.append(height_in_cm);  buf.append(",");
			buf.append(weight_in_kg);  buf.append(",");
			buf.append(race);  buf.append(",");
			buf.append(ethnicity);  buf.append(",");
			buf.append(tumor_site);  buf.append(",");
			buf.append(tissue_type);  buf.append("\n");

			return buf.toString();
		}
	}

	public String toCSV() {
		StringBuffer buf = new StringBuffer();
		buf.append("slide_id,");
		buf.append("specimen_id,");
		buf.append("tumor_code,");
		buf.append("case_id,");
		buf.append("gender,");
		buf.append("age,");
		buf.append("height_in_cm,");
		buf.append("weight_in_kg,");
		buf.append("race,");
		buf.append("ethnicity,");
		buf.append("tumor_site,");
		buf.append("tissue_type\n");

		for (SlideMetadata slideMetadata : slideMetadataBySlideId.values()) {
			buf.append(slideMetadata.toCSV());
		}

		return buf.toString();
	}

	SortedMap<String,SlideMetadata> slideMetadataBySlideId = new TreeMap<String,SlideMetadata>();
	
	private String getJsonNumberOrStringAsString(JsonValue o) {
		return (o == null)
		    ? ""
			: (
				o instanceof JsonNumber
				? Integer.toString((int)(((JsonNumber)o).doubleValue()))
				: (o instanceof JsonString ? ((JsonString)o).getString() : "")
			  )
			;
	}

	/**
	 * <p>Load the CPTAC clinical data encoded in a JSON document that is an array of objects.</p>
	 *
	 * @param	document		the JSON document
	 * @throws	DicomException
	 */
	public void loadData(JsonArray document) throws ClassCastException {
		for (int i=0; i<document.size(); ++i) {
			JsonObject cptacCase = document.getJsonObject(i);
			if (cptacCase != null ) {
System.err.println("Have case");
				String       tumor_code = getJsonNumberOrStringAsString(cptacCase.get("tumor_code"));
				String          case_id = getJsonNumberOrStringAsString(cptacCase.get("case_id"));
System.err.println("Have case_id "+case_id);
				String           gender = getJsonNumberOrStringAsString(cptacCase.get("gender"));	// CPTAC-3 - "Male" | "Female"
				String              sex = getJsonNumberOrStringAsString(cptacCase.get("sex"));		// CPTAC-2 - "Male" | "Female"
				String              age = getJsonNumberOrStringAsString(cptacCase.get("age"));
				String     height_in_cm = getJsonNumberOrStringAsString(cptacCase.get("height_in_cm"));
				String     weight_in_kg = getJsonNumberOrStringAsString(cptacCase.get("weight_in_kg"));
				String             race = getJsonNumberOrStringAsString(cptacCase.get("race"));
				String        ethnicity = getJsonNumberOrStringAsString(cptacCase.get("ethnicity"));
				String       tumor_site = getJsonNumberOrStringAsString(cptacCase.get("tumor_site"));		// CPTAC-3
				String  site_of_disease = getJsonNumberOrStringAsString(cptacCase.get("site_of_disease"));	// CPTAC-2

				JsonArray specimens = (JsonArray)cptacCase.get("specimens");
				if (specimens != null) {
System.err.println("Have specimens size() = "+specimens.size());
					for (int sp=0; sp<specimens.size(); ++sp) {
						JsonObject specimen = specimens.getJsonObject(sp);
						String specimen_id = getJsonNumberOrStringAsString(specimen.get("specimen_id"));
System.err.println("Have specimen_id "+specimen_id);
						String tissue_type = getJsonNumberOrStringAsString(specimen.get("tissue_type"));		// CPTAC-3 - "tumor" or "normal"
System.err.println("Have tissue_type "+tissue_type);
						String specimen_type = getJsonNumberOrStringAsString(specimen.get("specimen_type"));	// CPTAC-2 - "tumor_tissue" or "normal_tissue"
System.err.println("Have specimen_type "+specimen_type);
						JsonArray slides = (JsonArray)specimen.get("slides");									// CPTAC-2
						if (slides != null) {
System.err.println("Have slides size() = "+slides.size());
							for (int sl=0; sl<slides.size(); ++sl) {
								JsonObject slide = slides.getJsonObject(sl);
								String image_path = getJsonNumberOrStringAsString(slide.get("image_path"));
System.err.println("Have image_path "+image_path);
								String slide_id = getJsonNumberOrStringAsString(slide.get("slide_id"));
System.err.println("Have slide_id");
								if (slide_id.length() > 0) {
System.err.println("Have slide_id "+slide_id);
									// for CPTAC-2, the slide_id is a simple non-unique index (e.g., "22") - won't work as unique index into map, and won't map from file name when doing DICOM conversion
									// so use image_path without svs suffix instead, if possible, else specimen_id-slide_id
									// https://www.techiedelight.com/how-to-remove-a-suffix-from-a-string-in-java/
									String index_slide_id = (image_path != null && image_path.endsWith(".svs")) ? image_path.substring(0, image_path.length() - ".svs".length()) : specimen_id + "-" + slide_id;
System.err.println("Using index_slide_id "+index_slide_id);
									SlideMetadata slideMetadata = new SlideMetadata(
										index_slide_id,
										specimen_id,
										tumor_code,
										case_id,
										(gender == null || gender.length() == 0) ? sex : gender,	// CPTAC-2 instead of gender
										age,
										height_in_cm,
										weight_in_kg,
										race,
										ethnicity,
										(tumor_site == null || tumor_site.length() == 0) ? site_of_disease : tumor_site,	// CPTAC-2 instead of tumor_site
										(tissue_type == null || tissue_type.length() == 0) ? specimen_type : tissue_type	// CPTAC-2 instead of tissue_type (different values, not always tumor or normal)
									);
									slideMetadataBySlideId.put(index_slide_id,slideMetadata);
								}
							}
						}
						else {
							String slide_id = getJsonNumberOrStringAsString(specimen.get("slide_id"));				// CPTAC-3
System.err.println("Have slide_id");
							if (slide_id.length() > 0) {
System.err.println("Have slide_id "+slide_id);
								SlideMetadata slideMetadata = new SlideMetadata(
									slide_id,
									specimen_id,
									tumor_code,
									case_id,
									gender,
									age,
									height_in_cm,
									weight_in_kg,
									race,
									ethnicity,
									tumor_site,
									tissue_type
								);
								slideMetadataBySlideId.put(slide_id,slideMetadata);
							}
						}
						// else ignore other types of specimens
					}
				}
			}
		}
	}

	/**
	 * <p>Load the CPTAC clinical data encoded in a JSON document.</p>
	 *
	 * @param	stream			the input stream containing the JSON document
	 * @throws	IOException
	 */
	public CPTACJSONAPIClinicalData(InputStream stream) throws IOException {
		JsonReader jsonReader = Json.createReader(stream);
		JsonArray document = jsonReader.readArray();
		jsonReader.close();
		loadData(document);
	}
	
	public String toString() {
		StringBuffer buf = new StringBuffer();
		for (SlideMetadata slideMetadata : slideMetadataBySlideId.values()) {
			buf.append(slideMetadata.toString());
		}
		return buf.toString();
	}

	/**
	 * <p>Read CPTAC clinical data encoded in a JSON document.</p>
	 *
	 * @param	arg one input path of the file containing the JSON metadata
	 */
	public static void main(String arg[]) {
		try {
			CPTACJSONAPIClinicalData data = new CPTACJSONAPIClinicalData(new FileInputStream(new File(arg[0])));
			{
				FileWriter csvw = new FileWriter(arg[1]);
				csvw.write(data.toCSV());
				csvw.close();
			}
			//System.err.print(data.toString());
		}
		catch (Exception e) {
			e.printStackTrace(System.err);
		}
	}
}
