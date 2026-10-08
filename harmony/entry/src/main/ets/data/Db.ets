import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LookupResult } from '../services/RelayClient';

let store: relationalStore.RdbStore | null = null;

const SCHEMA: string[] = [
  `CREATE TABLE IF NOT EXISTS media (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,
    name TEXT NOT NULL,
    path TEXT NOT NULL,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    media_id INTEGER NOT NULL,
    idx INTEGER NOT NULL,
    start_ms INTEGER NOT NULL,
    end_ms INTEGER NOT NULL,
    text TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS recordings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    segment_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    score INTEGER NOT NULL DEFAULT -1,
    detail TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    segment_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS vocabulary (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT NOT NULL,
    lemma TEXT NOT NULL DEFAULT '',
    pronunciation TEXT NOT NULL DEFAULT '',
    pos TEXT NOT NULL DEFAULT '',
    definition TEXT NOT NULL DEFAULT '',
    translation TEXT NOT NULL DEFAULT '',
    context TEXT NOT NULL DEFAULT '',
    context_translation TEXT NOT NULL DEFAULT '',
    ease REAL NOT NULL DEFAULT 2.5,
    interval_days INTEGER NOT NULL DEFAULT 0,
    due_at INTEGER NOT NULL,
    reps INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_key TEXT NOT NULL,
    title TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id INTEGER NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )`
];

export class Db {
  static async init(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: 'enjoy.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    store = await relationalStore.getRdbStore(context, config);
    for (let i = 0; i < SCHEMA.length; i++) {
      await store.executeSql(SCHEMA[i]);
    }
  }

  static get(): relationalStore.RdbStore {
    if (store === null) {
      throw new Error('database is not open');
    }
    return store;
  }
}

async function rows(sql: string, args: Array<relationalStore.ValueType>): Promise<relationalStore.ResultSet> {
  return Db.get().querySql(sql, args);
}

@Observed
export class MediaItem {
  id: number = 0;
  kind: string = 'audio';
  name: string = '';
  path: string = '';
  durationMs: number = 0;
  createdAt: number = 0;
}

@Observed
export class SegmentItem {
  id: number = 0;
  mediaId: number = 0;
  idx: number = 0;
  startMs: number = 0;
  endMs: number = 0;
  text: string = '';
}

@Observed
export class RecordingItem {
  id: number = 0;
  segmentId: number = 0;
  path: string = '';
  score: number = -1;
  detail: string = '';
  createdAt: number = 0;
}

@Observed
export class NoteItem {
  id: number = 0;
  segmentId: number = 0;
  content: string = '';
}

@Observed
export class VocabCard {
  id: number = 0;
  word: string = '';
  lemma: string = '';
  pronunciation: string = '';
  pos: string = '';
  definition: string = '';
  translation: string = '';
  context: string = '';
  contextTranslation: string = '';
  ease: number = 2.5;
  intervalDays: number = 0;
  dueAt: number = 0;
  reps: number = 0;
}

@Observed
export class ConversationItem {
  id: number = 0;
  agentKey: string = '';
  title: string = '';
  createdAt: number = 0;
}

@Observed
export class MessageItem {
  id: number = 0;
  conversationId: number = 0;
  role: string = '';
  content: string = '';
  createdAt: number = 0;
}

function col(row: relationalStore.ResultSet, name: string): number {
  return row.getColumnIndex(name);
}

export class MediaDao {
  static async list(): Promise<MediaItem[]> {
    const result = await rows('SELECT * FROM media ORDER BY created_at DESC', []);
    const items: MediaItem[] = [];
    try {
      while (result.goToNextRow()) {
        const item = new MediaItem();
        item.id = result.getLong(col(result, 'id'));
        item.kind = result.getString(col(result, 'kind'));
        item.name = result.getString(col(result, 'name'));
        item.path = result.getString(col(result, 'path'));
        item.durationMs = result.getLong(col(result, 'duration_ms'));
        item.createdAt = result.getLong(col(result, 'created_at'));
        items.push(item);
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async get(id: number): Promise<MediaItem | null> {
    const result = await rows('SELECT * FROM media WHERE id = ?', [id]);
    try {
      if (!result.goToNextRow()) {
        return null;
      }
      const item = new MediaItem();
      item.id = result.getLong(col(result, 'id'));
      item.kind = result.getString(col(result, 'kind'));
      item.name = result.getString(col(result, 'name'));
      item.path = result.getString(col(result, 'path'));
      item.durationMs = result.getLong(col(result, 'duration_ms'));
      item.createdAt = result.getLong(col(result, 'created_at'));
      return item;
    } finally {
      result.close();
    }
  }

  static async insert(kind: string, name: string, path: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'kind': kind,
      'name': name,
      'path': path,
      'duration_ms': 0,
      'created_at': Date.now()
    };
    return Db.get().insert('media', values);
  }

  static async updateDuration(id: number, durationMs: number): Promise<void> {
    await Db.get().executeSql('UPDATE media SET duration_ms = ? WHERE id = ?', [durationMs, id]);
  }

  static async remove(id: number): Promise<void> {
    const db = Db.get();
    await db.executeSql('DELETE FROM recordings WHERE segment_id IN (SELECT id FROM segments WHERE media_id = ?)', [id]);
    await db.executeSql('DELETE FROM notes WHERE segment_id IN (SELECT id FROM segments WHERE media_id = ?)', [id]);
    await db.executeSql('DELETE FROM segments WHERE media_id = ?', [id]);
    await db.executeSql('DELETE FROM media WHERE id = ?', [id]);
  }
}

export class SegmentDao {
  static async list(mediaId: number): Promise<SegmentItem[]> {
    const result = await rows('SELECT * FROM segments WHERE media_id = ? ORDER BY idx ASC', [mediaId]);
    const items: SegmentItem[] = [];
    try {
      while (result.goToNextRow()) {
        const item = new SegmentItem();
        item.id = result.getLong(col(result, 'id'));
        item.mediaId = result.getLong(col(result, 'media_id'));
        item.idx = result.getLong(col(result, 'idx'));
        item.startMs = result.getLong(col(result, 'start_ms'));
        item.endMs = result.getLong(col(result, 'end_ms'));
        item.text = result.getString(col(result, 'text'));
        items.push(item);
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async replace(mediaId: number, cues: SegmentItem[]): Promise<void> {
    const db = Db.get();
    db.beginTransaction();
    try {
      await db.executeSql('DELETE FROM recordings WHERE segment_id IN (SELECT id FROM segments WHERE media_id = ?)', [mediaId]);
      await db.executeSql('DELETE FROM notes WHERE segment_id IN (SELECT id FROM segments WHERE media_id = ?)', [mediaId]);
      await db.executeSql('DELETE FROM segments WHERE media_id = ?', [mediaId]);
      for (let i = 0; i < cues.length; i++) {
        const cue = cues[i];
        const values: relationalStore.ValuesBucket = {
          'media_id': mediaId,
          'idx': i,
          'start_ms': cue.startMs,
          'end_ms': cue.endMs,
          'text': cue.text
        };
        await db.insert('segments', values);
      }
      db.commit();
    } catch (e) {
      db.rollBack();
      if (e instanceof Error) {
        throw e;
      }
      throw new Error('failed to save segments');
    }
  }
}

export class RecordingDao {
  static async latest(segmentId: number): Promise<RecordingItem | null> {
    const result = await rows('SELECT * FROM recordings WHERE segment_id = ? ORDER BY id DESC LIMIT 1', [segmentId]);
    try {
      if (!result.goToNextRow()) {
        return null;
      }
      const item = new RecordingItem();
      item.id = result.getLong(col(result, 'id'));
      item.segmentId = result.getLong(col(result, 'segment_id'));
      item.path = result.getString(col(result, 'path'));
      item.score = result.getLong(col(result, 'score'));
      item.detail = result.getString(col(result, 'detail'));
      item.createdAt = result.getLong(col(result, 'created_at'));
      return item;
    } finally {
      result.close();
    }
  }

  static async insert(segmentId: number, path: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'segment_id': segmentId,
      'path': path,
      'score': -1,
      'detail': '',
      'created_at': Date.now()
    };
    return Db.get().insert('recordings', values);
  }

  static async updateScore(id: number, score: number, detail: string): Promise<void> {
    await Db.get().executeSql('UPDATE recordings SET score = ?, detail = ? WHERE id = ?', [score, detail, id]);
  }
}

export class NoteDao {
  static async get(segmentId: number): Promise<NoteItem | null> {
    const result = await rows('SELECT * FROM notes WHERE segment_id = ? ORDER BY id DESC LIMIT 1', [segmentId]);
    try {
      if (!result.goToNextRow()) {
        return null;
      }
      const item = new NoteItem();
      item.id = result.getLong(col(result, 'id'));
      item.segmentId = result.getLong(col(result, 'segment_id'));
      item.content = result.getString(col(result, 'content'));
      return item;
    } finally {
      result.close();
    }
  }

  static async save(segmentId: number, content: string): Promise<void> {
    const existing = await NoteDao.get(segmentId);
    if (existing === null) {
      const values: relationalStore.ValuesBucket = {
        'segment_id': segmentId,
        'content': content,
        'created_at': Date.now()
      };
      await Db.get().insert('notes', values);
      return;
    }
    await Db.get().executeSql('UPDATE notes SET content = ? WHERE id = ?', [content, existing.id]);
  }
}

export class VocabDao {
  static async list(): Promise<VocabCard[]> {
    return VocabDao.query('SELECT * FROM vocabulary ORDER BY created_at DESC', []);
  }

  static async due(now: number): Promise<VocabCard[]> {
    return VocabDao.query('SELECT * FROM vocabulary WHERE due_at <= ? ORDER BY due_at ASC', [now]);
  }

  static async insert(result: LookupResult, context: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'word': result.word,
      'lemma': result.lemma,
      'pronunciation': result.pronunciation,
      'pos': result.pos,
      'definition': result.definition,
      'translation': result.translation,
      'context': context,
      'context_translation': result.contextTranslation,
      'ease': 2.5,
      'interval_days': 0,
      'due_at': Date.now(),
      'reps': 0,
      'created_at': Date.now()
    };
    return Db.get().insert('vocabulary', values);
  }

  static async updateSchedule(id: number, ease: number, reps: number, intervalDays: number, dueAt: number): Promise<void> {
    await Db.get().executeSql(
      'UPDATE vocabulary SET ease = ?, reps = ?, interval_days = ?, due_at = ? WHERE id = ?',
      [ease, reps, intervalDays, dueAt, id]
    );
  }

  static async remove(id: number): Promise<void> {
    await Db.get().executeSql('DELETE FROM vocabulary WHERE id = ?', [id]);
  }

  private static async query(sql: string, args: Array<relationalStore.ValueType>): Promise<VocabCard[]> {
    const result = await rows(sql, args);
    const items: VocabCard[] = [];
    try {
      while (result.goToNextRow()) {
        const item = new VocabCard();
        item.id = result.getLong(col(result, 'id'));
        item.word = result.getString(col(result, 'word'));
        item.lemma = result.getString(col(result, 'lemma'));
        item.pronunciation = result.getString(col(result, 'pronunciation'));
        item.pos = result.getString(col(result, 'pos'));
        item.definition = result.getString(col(result, 'definition'));
        item.translation = result.getString(col(result, 'translation'));
        item.context = result.getString(col(result, 'context'));
        item.contextTranslation = result.getString(col(result, 'context_translation'));
        item.ease = result.getDouble(col(result, 'ease'));
        item.intervalDays = result.getLong(col(result, 'interval_days'));
        item.dueAt = result.getLong(col(result, 'due_at'));
        item.reps = result.getLong(col(result, 'reps'));
        items.push(item);
      }
    } finally {
      result.close();
    }
    return items;
  }
}

export class ChatDao {
  static async list(): Promise<ConversationItem[]> {
    const result = await rows('SELECT * FROM conversations ORDER BY id DESC', []);
    const items: ConversationItem[] = [];
    try {
      while (result.goToNextRow()) {
        const item = new ConversationItem();
        item.id = result.getLong(col(result, 'id'));
        item.agentKey = result.getString(col(result, 'agent_key'));
        item.title = result.getString(col(result, 'title'));
        item.createdAt = result.getLong(col(result, 'created_at'));
        items.push(item);
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async create(agentKey: string, title: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'agent_key': agentKey,
      'title': title,
      'created_at': Date.now()
    };
    return Db.get().insert('conversations', values);
  }

  static async rename(id: number, title: string): Promise<void> {
    await Db.get().executeSql('UPDATE conversations SET title = ? WHERE id = ?', [title, id]);
  }

  static async remove(id: number): Promise<void> {
    await Db.get().executeSql('DELETE FROM messages WHERE conversation_id = ?', [id]);
    await Db.get().executeSql('DELETE FROM conversations WHERE id = ?', [id]);
  }

  static async messages(conversationId: number): Promise<MessageItem[]> {
    const result = await rows('SELECT * FROM messages WHERE conversation_id = ? ORDER BY id ASC', [conversationId]);
    const items: MessageItem[] = [];
    try {
      while (result.goToNextRow()) {
        const item = new MessageItem();
        item.id = result.getLong(col(result, 'id'));
        item.conversationId = result.getLong(col(result, 'conversation_id'));
        item.role = result.getString(col(result, 'role'));
        item.content = result.getString(col(result, 'content'));
        item.createdAt = result.getLong(col(result, 'created_at'));
        items.push(item);
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addMessage(conversationId: number, role: string, content: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'created_at': Date.now()
    };
    return Db.get().insert('messages', values);
  }

  static async updateMessage(id: number, content: string): Promise<void> {
    await Db.get().executeSql('UPDATE messages SET content = ? WHERE id = ?', [content, id]);
  }
}
