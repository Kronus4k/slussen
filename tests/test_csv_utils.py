from pipeline_core.csv_utils import count_csv_records


def write_csv(tmp_path, text):
    path = tmp_path / "sample.csv"
    path.write_text(text, encoding="utf-8")
    return path


def test_counts_simple_rows(tmp_path):
    path = write_csv(tmp_path, "id,name\n1,a\n2,b\n")
    assert count_csv_records(path) == 2


def test_quoted_line_break_is_one_record(tmp_path):
    path = write_csv(tmp_path, 'id,comment\n1,"line one\nline two"\n2,ok\n')
    assert count_csv_records(path) == 2


def test_header_only_file_has_zero_records(tmp_path):
    path = write_csv(tmp_path, "id,name\n")
    assert count_csv_records(path) == 0